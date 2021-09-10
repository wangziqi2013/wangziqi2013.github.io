---
layout: paper-summary
title:  "Catalyzer: Sub-Millisecond Startup for Serverless Computing with Initialization-Less Booting"
date:   2021-09-09 01:49:00 -0500
categories: paper
paper_title: "Catalyzer: Sub-Millisecond Startup for Serverless Computing with Initialization-Less Booting"
paper_link: https://dl.acm.org/doi/10.1145/3373376.3378512
paper_keyword: Microservice; Serverless; OS; Process Template
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

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
snapshot image (although the paper does not discuss why this is necessary).
Later instances of the VMM can simply map the file into its own address space with mmap(), and then work on this
snapshot as its main memory image.

The first contribution of the paper, namely overlay memory, optimizes on image sharing when multiple VMM instances
work on the same snapshot image. According to isolation rule, and also to protect the integrity of the snapshot
image, all modifications to the snapshot image must not be reflected on the image itself, but instead, should be 
applied to a newly allocated page belonging to the VMM instance that issues the access.

