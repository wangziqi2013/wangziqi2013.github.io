---
layout: paper-summary
title:  "Catalyzer: Sub-Millisecond Startup for Serverless Computing with Initialization-Less Booting"
date:   2021-09-09 01:49:00 -0500
categories: paper
paper_title: "Catalyzer: Sub-Millisecond Startup for Serverless Computing with Initialization-Less Booting"
paper_link: https://dl.acm.org/doi/10.1145/3373376.3378512
paper_keyword: Microservice; Serverless; OS; Process Template; Catalyzer
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. VMM instances must not write the original snapshot image, and needs to perform CoW when writing to the page for 
   the first time. This is not part of regular CoW (because these pages can be marked writable in the base snapshot's 
   page table), and should be achieved with a shadow page table that tracks the status of private pages allocated for 
   CoW.

2. Pointers need to be relocated when mapping a snapshot into the virtual address space, because the underlying 
   physical location may have changed from what is was when the snapshot was taken. 
   This requires pointer relocation, and can be achieved with a relocation table just like in dynamic libraries.
   (I am not 100% sure about the relocation part, and neither did the paper state it clearly which metadata must 
   be updated after restoring a snapshot.)

3. I/O needs to be reconnected after restoring a snapshot, because I/O states are dependent also on external states
   that are not part of the snapshot. This can be done lazily only on occasions when the I/O resource is 
   actually used by the application. The OS can use a table to track the reconnection status of I/O handlers.

4. Classic fork() cannot handle multi-threaded language runtimes. This can be achieved by dumping thread states
   first and then canceling the threads, before fork() is called. Threads are restarted using the dumped states
   after fork().

5. This paper reads like the [SOCK paper]({% post_url 2021-09-10-sock %}), from the way they conducted research and 
   the motivation, to the set of proposed optimizations and the overall structure of the paper, only
   that this paper optimizes VMM while the SOCK paper is about thin containers.

<!--
**Comments:**

1. This paper is very loosely organized and hard to read. While I definitely acknowledge the contributions
   made by the authors, and judging from the author list, it seems that the contributions in this paper have already 
   been applied in industrial production systems, which is impressive and stronger than plain talking.
   But, on the other hand, I do suggest the authors to further think on the motivation and the key insights of the 
   approach, especially the high-level insights, or let's say, what could readers learn from this paper? What is
   the take-away message? I could not find any in this paper.
   Also, I appreciate the individual ideas presented in this paper, and I understand that the authors just applied 
   a series of techniques to reduce startup latency for serverless environment, but these ideas should be more
   organized, and be discussed under a few common topics (e.g., reducing VMM initialization latency, reducing language 
   environment latency, etc.).
   The current paper just makes it look like these techniques are just ad-hoc patches that you randomly found 
   working via trial-and-error, and do not have a common goal to optimize on.
   For example, how does sfork(), which is to optimize fork() based optimization, relate to the earlier discussion 
   of the paper, which is mainly about snapshotting? 
   Besides, many paragraphs lack an opening and conclusion. Why is the paragraph important? What is the conclusion of 
   the paragraph?

2. The paper makes conflicting claims. 
   Insight 1 says "most of the startup latency comes from application initialization", then in Sec. 2.2 it says 
   "sandbox initialization is stable for different workloads and dominates the latency overhead for
    simple functions like Python Hello."
   I understand that these two might both be correct, because they have different assumptions. But in this case, why do
   you even mention the "Python Hello" case that is neither representative, nor further explored in the paper?

3. Some terminology usages are confusing. For example, what is a "critical section" in Fig. 8(a)?
   Sec. 3.3, "I/O reconnection is performed asynchronously on the restore critical path" -- what does "asynchronously" mean? Why it is on the critical path if asynchronously?
   Sec. 3.1, what is "two layered EPT"? 

4. The paper proposes concepts but never discusses them.
   Cold boot, warm boot, fork boot are proposed in Sec. 2.3, and then only mentioned at a few extra locations later.
   So what are the overall picture of these booting techniques?
   Similarly, sfork() is proposed in the beginning of Sec. 4, and never discussed again, e.g., how do you incorporate
   techniques discussed later in Sec. 4 into your sfork()?

5. Many important design decisions are unjustified. For example, why do you need to reconnect the I/O? 
   Why does metadata need to be stored separately rather than just within the snapshot image?
   Readers are not all experts in certain implementations of the VMM. At least give a few points on why previous
   approaches do this and why they are hard to avoid (which also highlights your contribution).
-->

This paper proposes Catalyzer, a software framework for reduced serverless startup latency. The paper is motivated by
the fact that most existing commercial platforms and proposals suffer either long VMM initialization time, or 
long application environment setup time, which are, when combined, called the "cold boot latency". 
Most previous approaches on optimizing the cold boot latency of serverless functions only optimize one of the two
components of cold boot latency, leaving the other one as the new bottleneck.
This paper, instead, addresses cold boot latency from both aspects with a unified caching approach and careful 
engineering.

The paper discusses three key insights in optimizing cold boot latency. First, as virtualization techniques become
more and more lightweight, application startup cost has become a dominating factor in the cold boot latency of
serverless functions. Here, application startup refers to the initialization of software runtimes, such as interpreters,
and the import of libraries. This part is hard to avoid in serverless functions without significantly changing the 
internal mechanism of the interpreter.
Second, there is a clear division between the initialization stage (both OS and interpreter) and the function 
execution stage on the memory states and OS handlers that they access. In other words, these two stages use a largely
disjoint set of states and handlers. 
Lastly, it is also observed that serverless functions using the same language have the same state to begin with
before the function is executed, since they have the same initialization sequence. Different function instances may
just be spawned from this initialized state, rather than repeating the same initialization sequence every time an
instance is created.

The paper also identifies limitations of previous researches.
First, previous works attempted to accelerate application startup by caching the initialized state of the interpreter.
While this reduces the latency of interpreter initialization, it has two flaws. The first flaw is that caching will
consume significant storage and increase the memory footprint of the serverless, as each language environment needs 
one cached copy. The second flaw is that application-level caching is not capable of reducing the latency of 
system startup.
Second, previous work has also worked on reducing the initialization cost of the system and/or the container/VMM
with lightweight virtualizations, special kernels, etc. These approaches, while effective in reducing the 
system startup cost, cannot optimize application-level latency, which can become the dominating overhead.
Lastly, there are also previous works that optimize at both application and system level by taking snapshots of the
entire system state after initialization, capturing the initialized state of both the system and application. 
The paper points out, however, that this approach has engineering difficulties. For example, these snapshot images are
typically compressed and serialized, which incurs extra overhead for restoration. In addition, certain operations,
such as opened files, need to be "redone" after the snapshot is restored (dubbed "reestablish the I/O"), due to the 
fact that I/O operations also depend on the state of external entities or devices that are not included in the snapshot.

Catalyzer consists of a set of patches that fix the issues with snapshotting discussed above. Catalyzer
is based on a lightweight VMM, and adopts the snapshotting approach for saving and restoring the memory and contextual
states of a serverless execution.
As in previous snapshotting approaches, snapshots are generated and stored to persistent storage as file objects.
Metadata such as OS internal states are stored separately as metadata, and needs to be restored after loading the 
snapshot image (maybe because they are location dependent, and hence pointer values should not be taken literally).
Later instances of the VMM can simply map the file into its own address space with mmap(), and then work on this
snapshot as its main memory image.

The first contribution of the paper, namely overlay memory, optimizes on image sharing when multiple VMM instances
work on the same snapshot image. According to isolation rule, and also to protect the integrity of the snapshot
image, all modifications to the snapshot image must not be reflected on the image itself, but instead, should be 
applied to a newly allocated page belonging to the VMM instance that issues the access.
To this end, Catalyzer maintains a shadow page table in addition to the standard hardware page table. The 
shadow table tracks pages that have been modified and hence allocated for CoW. The hardware page table for the 
VMM is then updated accordingly using the shadow table, if there is an entry, or the base page table if otherwise.

The second contribution optimizes state restoration of OS metadata. In conventional approaches, these metadata is 
stored separately and serialized. Before restoration they need to be deserialized, and then reapplied to the 
memory image (as discussed above, I guess this is because some states are location dependent, such as pointers,
and hence their value must be relocated just like when you load a dynamic library). 
To avoid such overhead, the paper proposes that the states should be stored as-is in the snapshot image, 
but in addition to that, an extra relocation table (called the relation table in the paper) should also be added
which tracks the location and values of all the pointers. The original base of the snapshot is also stored somewhere.
Pointer relocation then becomes as simple as scanning the relocation table, and for each entry, adjusting the pointer
value by adding the difference between load addresses onto the value.

The next contribution is on-demand I/O reconnection, which aims at optimizing the resource-consuming I/O reconnect
step after restoring a snapshot image. I/O reconnect is necessary, as the internal I/O states also depend on external
entities such as files and TCP states on the other end. The paper observes that, however, that most of the I/O states
will not be used by the serverless function after restoration. Reestablishing the I/O can be performed lazily only when
the application actually uses I/O. To achieve this, the paper proposes adding a table tracking the shadowed I/O states.
An I/O connection can in one of the three states: Active, closed, or active but not yet reconnected. After
restoration, all active I/O connections are marked as "active but not yet reconnected". When the application requests
for I/O using one of the I/O connections, their states will transit to "active", after I/O connection is performed 
lazily.

The paper also proposes a new OS primitive, sfork() (which stands for "sandbox fork()"), which has the same 
high-level behavior of fork(), i.e., creating a new process using an existing one as the template, sharing the 
address space as well as file handlers, but differs significantly from fork() in certain semantics. 
The paper argues that although fork() is generally useful for reducing the latency of serverless, as it can just 
hot-copy an existing VMM instance and use it to fulfill an incoming request, the fact that fork() does not work
for multi-threaded applications and that the process will still share opened files can defeat the purpose of 
VMM (e.g., isolation). 
The paper proposes two features of sfork() that overcome fork()'s problems.
First, multi-threaded programs should first cancel their threads except the main thread, after dumping the 
thread states that help recovering these threads after the fork(). After a conventional fork(), which is the system
call that underlies sfork(), is executed, these threads are restarted using the thread states they have dumped earlier.
Second, shared files are accessed via a file server, which only grants read-only access. After fork(), the file
handler is still available, but it does not break isolation, because the file handler inherited from the parent
process is read-only.
