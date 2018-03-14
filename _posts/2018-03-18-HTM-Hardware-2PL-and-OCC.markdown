---
layout: post
title:  "Hardware Transactional Memory: Hardware Two Phase Locking and Optimistic Concurrency Control"
date:   2018-03-09 03:32:00 -0500
---

### Introduction

Hardware transactional memory (HTM) [1] eases parallel programming through built-in support for 
conflict serializable (CSR) transactional semantics directly on the hardware level. Concurrency control (CC) is a 
family of implementation independent algorithms that achieve transactional semantics by the scheduling of state-dependent operations. 
In the discussion that follows, we focus on a page based model where only reads and writes are state-dependent.
Several software implemented CC mechanisms are already deployed in applications such as database management systems,
including Two Phase Locking (2PL), Optimistic CC (OCC), and Multiversion CC (MVCC). In this literature, we 
explore the design space of CC algorithms in hardware. We first review a few hardware features that can serve as
building blocks for hardware CC algorithms. Then based on these hardware features, we incrementally build an HTM 
that provides correct transactional semantics, with increased degrees of parallelism. 

To make the discussion more compact and coherent, only 2PL and OCC are covered, as they share some characteristics that 
can simplify the explanation. MVCC will be discussed in another literature. In addition, we assume logical transactions are bound to 
different processors, and that they can finish within a scheduling quantum. Virtualizing hardware transactions [2] to allow context 
switch, interruption or migration to happen amid their executions is a relevant topic, but not covered. Since this
literature is concentrated on the concurrency control aspect of HTM, we assume the transaction's working set
fits in processor's L1 cache. Although unbounded transactional memory [3] is an interesting topic, and does have an effect on
hardware CC algorithms, we postpone this topic to a later discussion.

### Hardware Locking

In a multiprocessor system, to ensure coherence of cached data while allowing every processor to manipulate data in its private L1 cache, 
hardware already implements a multi-reader, single-writer locking protocol for each individual cache line, dubbed "cache coherence 
protocol". We use MSI as an example. When a cache line is to be read by the cache controller, the controller sends a load-shared message 
to either the bus or the 
directory. The controller will be granted the permission to read through one of the following paths: (1) There are no sharing 
processors. The requestor will be granted "S" state. (2) There are several sharing processors in "S" state. The requestor will also be 
granted "S" state. (3) There is exactly one processor that has the cache line in the exclusive "M" state. In this case, the write 
permission will first be revoked by the coherence protocol, and then the requestor is granted "S" state (and will receive the dirty cache 
line via a cache-to-cache transfer). A similar process will be followed 
if the requesting controller is to write into the cache line. Instead of granting an "S" state, the protocol revokes all other cache 
lines regardless of their state, and then grants "M" state to the requestor. Note that the protocol described here is not optimal.
For instance, converting an "M" state to "S" after a write-back and graning "S" to the requestor of read permission could be more 
efficient. We deliberately avoid write-backs in the discussion, because under the context of HTM, write-backs usually require some 
indirection mechanism which is out of the scope of discussion. 

If we treat transactional "S" state as holding a read lock on a cache line, and transactional "M" state as holding an exclusive write 
lock ("transactional" implies an extra bit is needed to represent that the line is part of an active transaction), then the MSI 
protocol is exactly a hardware implementation of preemptive reader/writer locking. Compared with software reader/writer locking,
instead of the requestor of a conflicting lock mode waiting for the current owner to release the lock, which may incur deadlock and 
will waste cycles, the hardware choose not to wait, but just to cooperatively preempt. Here the word "cooperatively" means the 
current owner of the lock is aware of the preemption via the cache coherence message. As we shall see later, the cooperative 
nature of hardware preemption helps in designing an efficient protocol.

### Two Phase Locking

Since preemptive reader/writer locking is already implemented on the heardware level via cache coherence, it should not be too
diffcult to implement two phase locking (2PL) on top of this. Indeed, what 2PL requires is simple: (s1) All read/write operations
to data items should be protected by locks of the corresponding mode; (s2) No locks shall be released before the last acquire of
a lock, thus dividing the entire execution into a grow phase, where locks are only acquired, and a shrink phase, where locks are only
released. It is also correct to make (s2) more restrictive: (s2') Locks are acquired 
as we access data items, but no locks shall be released before the final commit point. (s1)(s2) is the general form of 2PL, 
granting the full scheduling power of the 2PL family, while (s1)(s2') is called strong strict 2PL, or SS2PL. There is actually a midpoint,
(s2'') Locks are acquired as we access data items, and no **writer** locks shall be released before final commit point. Reader locks 
shall not be released before the last lock acquire as in 2PL. (s1)(s2'') is called strict 2PL, or S2PL.

Translating the above 2PL principle into hardware terminologies, we obtain the following for hardware transactions: 
(h1) All transactional load/store instructions must use cache coherence protocol to obtain permission to the cache line
under the corresponding state; (h2) Before acquiring the last cache line used by the transaction, no transactional cache line shall be
evicted by the cache controller, either because of capacity/conflict misses, or because some other processors intend to 
invalidate the line. This seems to be only a trivial improvement over the existing cache coherence protocol, and the correctness
is straightforward, as (h1)(h2) can be mapped to (s1)(s2). One of the gratest advantages of this simple design is the fact 
that cache coherence remains unchanged, and in practice, hardware manufacturers are reluctant to revise the coherence 
protocol. 

There are still two obstacles, however, that prevents the above hardware 2PL design from being implemented. First, hardware locking
is preemptive, and if two transactions conflict, i.e. one requests a cache line held by another in a conflicting state, the 
coherence protocol can do nothing but to fulfill the request, causing a 2PL violation on the latter. While software 2PL
allows transactions to wait for a lock, on the contrary, the best that hardware can do is to abort the 
violated transaction, and retry. This "abort-on-conflict" scheme is called "requestor-win". An alternative but symmetric 
solution is to abort the requesting transaction. If this is to be supported, the cache coherence protocol should be 
slightly modified by adding a "negative acknowledgement" (NACK) signal. The cache line owner asserts this signal 
if a coherence request of confliting mode is received. The requestor then aborts. In general, deciding which transaction
to abort on a conflict is non-trivial. Care should be taken that wasted works are minimized, and that no livelock or 
starvation shall happen. Some proposals introduce hardware and/or software arbitrators, which take the age, priority, etc.,
of conflicting transactions into consideration for making abort decisions.

The second obstacle of implementing hardware 2PL derives from (h2), which says no transactional cache line shall be evicted before the 
last coherence request on behave of transactional load/store operations. With only load/store/commit instruction sequences, and without 
higher level semantics of the logical transaction, hardware is generally unable to determine when the last request would be.
An easy fix is to strengthen (h2) a little into (h2'): no transactional cache line shall be evicted before the commit instruction.
Not surprisingly, (h1)(h2') are just hardware SS2PL.

One extra bouns of adopting hardware SS2PL is recoverability, which is of crucial importance to HTM. Releasing
a transactionally written cache line to other transactions before commit is allowed by 2PL, as in (h2), but
it causes the "dirty read" problem. Those who has read dirty cache lines of an uncommitted transaction must thererfore 
form a "commit dependency" to the source transaction, and can only commit after the source transaction commits. 
Otherwise, if the source transaction later aborts, the execution becomes non-serializable.

### 2PL Limitations

Although correctness of transactional semantics is guaranteed by holding locks on cache lines 
till tranaction commit as in SS2PL, this scheme does not often provide high degrees of parallelism. There
are two reasons. First, long running transactions, or transactions working on "hot" data items, are more prone
to suffering from frequent aborts, as a single conflict can force them to abort. Second, in the hardware SS2PL scheme,
conflicts are resolved by transaction aborts as early as they are detected. On one hand, such "eager" conflict 
detection and resolution mechanism make sure that transactions who violates 2PL will not waste cycles executing 
the rest of its work, minimizing wastages locally. On the other hand, if the "winner" transaction that won
an arbitration is eventually aborted, then we actually might have at least some useful work done if the "loser" of
the arbitration were allowed to continue. 

The first observation motivates the adoption of weaker semantic levels, such as Snapshot Isolation (SI). 
There exists HTM proposals that only supports SI [4], but in order for programs written for generic HTM to
be portable, diagnostics tools must be provided to ensure SI induced anomalies do not occur. 
The latter observation suggests an alternative conflict detection (CD) and 
resolution (CR) mechanism that are "lazy". Transactions with lazy CD/CR check serialization conditions only at 
the point they are absolutaly necessary, after which the execution cannot be undone and/or may become undefined. 
We take a closer look at lazy CD/CR In the following discussion.

### To Lock or Not to Lock: It's an OCC Question

Lazy CD/CR shares lots of characteristics with Optimistic Concurrency Control (OCC) [5]. Instead of locking every
data item till transaction commit to prevent conflicting accesses by other transactions,
OCC optimistically assumes that the **transaction's read set will not be altered during its 
execution (from the first read to the last read)**, and therefore locking is omitted. 
In later sections We will see how the validity of this assumption is checked.
Read set (RS) refers to the set of data items that a
transaction accesses without modifying the content. Correspondingly, write set (WS) refers to the set of data items
that a transaction wishes to write into. It is not strictly required that WS is a subset of RS, because in practice,
blind writes (writing a data item without reading its value in the same transaction) are not uncommon. Both RS and WS
are maintained as sets of (addr., data) pairs.

To ensure recoverability, transactions refrian from globally making the write set visible before its commit status is
determined. As mentioned in a previous section, SS2PL manitains this property by not releasing locks on dirty data items
until transaction commit point. In OCC, access controls are not imposed on individual data items. 
Transactionally written data must be buffered in the WS locally before the transaction is able to commit.

The execution of an OCC transaction is therefore divided into three phases. In the first phase called the "read phase",
transactionally read data items are either obtained from the global state, or forwarded from its WS if the item is dirty.
Transactionally written items are buffered in the local WS.
No global state changes are made in this phase, and hence if transactions abort after the read phase, no roll back on
the global state is required. 

In the second phase, the validation phase, transactions validate their RSs to ensure read phases
are atomic with regard to concurrent writes to the global state. Note that the "atomic read phase w.r.t. concurrent writes" 
statement is simply a rephrase of the OCC assumption: The RS will not be altered during the read phase. A transaction
becomes "invincible" once it successfully validates, as the commit status has been determined, and it can no longer abort. 

In the last phase, the write phase, transactions publicize their WSs by writing all dirty data items back to the 
global state. Transactions cannot be rolled back during the write phase. 

### Hardware Read/Write Set

In a minimal design, the hardware implements RS in its L1 private cache, as cache coherence already maintains
the muti-reader property. Transactions mark the "Transactionally Read" (TR) bit on transactional loads, and no
extra structure is maintained. Note that the RS does not include dirty data items forwarded from the WS. 
WSs are more tricky, because it must serve two purposes. The first is to forward dirty data to load instructions, as
described earlier. The WS structure must therefore support efficient lookups with load addresses. 
The second purpose is to store speculative data items and their addreses, which can be walked efficiently
during the write phase and possibly during the validation phase. Apparently, iteration of all elements
in the WS must also be supported efficiently. Optionally, if more than one store instructions modify a data item
transactionally, instead of logging multiple entries, the WS may consolidate them onto the same entry,
saving WS storage. This requires efficient lookups using store addresses.

The granularity of RS/WS maintenance may affect conflict rates. For example, RSs are implicitly maintained 
on cache line granularity in the previous paragraph. Conflict rates can increase due to false sharing. The justification, 
however, is that read locality and design simplicity may offset the negative effect. On the other hand, 
if WSs use cache line addresses, then the entire cache line must be logged as speculative data. Essentially,
the transactional store instruction is expanded into a few load instructions to bring in the cache line, and 
then a few store instructions to overwrite the cache line, preserving all other contents while updating the intended word. 
Not only Write-after-Write (WAW) conflict rate increases in this case, but also Read-after-Write (RAW) and Write-after-Read (WAR).
In the following discussion, we assume that load/store addresses are word-aligned, because otherwise, a load may access half-speculative 
and half-non-speculative data, complicating the explanation.

Overall, the WS can be implemented in one of the following ways: (1) Speculative data and addresses are decoupled. 
Data items are stored in a linear log consisting of (addr., data) paris as in LogTM [8], or a software hash table as in 
SigTM [9]. To support efficient lookup using load/store addresses, a filter is checked before a linear search. 
The filter can be a bloom filter as in VTM [6], or a fast cache of recently accessed items, or a BULK-style signature [7] 
that supports efficient membership testing, intersection, and reconstruction. The log can be virtualized, can be accelerated 
by a hardware queue, or can be cache allocated. (2) Keep the WS in the L1 private cache, and optionally "virtualize" the 
cache to support overflowing transactional states into lower memory hierarchy. Virtualizing transactional states is not covered
in this literature, and we focus on the former. To support L1 resident speculative data, the cache coherence protocol
is modified to treat transactional store coherence request as a load-shared request. Multiple readers and multiple speculative writers can co-exist under the modified protocol. Note that speculative cache lines cannot be sent to fulfill load-shared requests.

The RS, if not to be implemented as part of L1 tags, can similarly be maintained as a signature or bloom filter. 
RSs do not have to be exact, as long as false negatives are impossible, and false positives are tolerable. 
Depending on the type of the validation protocol, transactional loaded data as well as an exact log may also be 
required, in which case all techniques for maintaining WSs can also be adopted for RSs.

With RS and WS implemented, the read phase proceeds as follows. On transactional load, first check the WS. If 
the address hits the WS, then forward from the WS. Otherwise, use cache coherence protocol to obtain shared permission
of the cache line. Meanwhile, The address is inserted into the RS. On transactional store, insert the address and 
speculative data into the WS. On external abort or abort instruction, no roll back is needed, as all changes are 
local. If transactional execution eventually reaches the commit instruction, then validation is performed,
which is covered in the next section.



Alternatively,
validation can also be carried out by locking the WS (i.e. blocking all accesses to data items in the WS) 
first, and then broadcasting the WS to all other transactions currently under the read phase. Transactions whose 
RS has a non-empty intersection with the broadcasted WS then abort. The lock on the WS will not be 
released until write phase finishes, as we shall see later. 

The first validation algorithm is called Backward OCC (BOCC), as it verifies the intergity of RSs by intersecting
the RS against WS of already committed transactions. A non-empty intersection implies a possible non-atomic read phase.

In general, read validation is performed if a reader has acquired a cache line in shared mode without locking it using 2PL
principle, i.e. the reader allows other txns to access the cache line by acquiring exclusive ownership before the reader commits. 
In 2PL, the read lock prevents another txn from setting a write lock and writing into the cache line, and hence 
serializing itself after the reader txn. This could potentially lead to a cyclic dependency if the reader later establishes a reverse 
dependency with the writer txn by reading the same cache line again, or reading another cache line updated by the writer, 
or writing into any updated cache line. If the reader optimistically assumes no writer modifies the cache line, and hence
does not require the cache line to stay in L1 private cache till txn commit point which is equivalent to holding a read lock and 
only releasing the lock after commit, then it either 
needs to check the validity of the cache line after the last usage of it, or 
somehow let the first writer of the cache line notify readers that the assumption no long holds before the writer publishing its first 
write on the cache line. For lazy versioning, this happens on validation stage, and for eager versioning, this happens on the first 
transactoinal write. If we implement the former, reader txns may not realize the fact that it has read inconsistent state until 
validation, resulting in what we call as "zombine" txns, as the reader now bases its action on a set of data that should never
occur as inputs in a serial environment. The result of zombie execution is, in general, undefined.

If you are familiar with Optimistic Concurrency Control (OCC), the two ways of validating read sets are exactly
two flavors of OCC: If reader txns validate their read sets before the write phase, then it is Forward OCC (FOCC), because reader 
checks its read set against those txns that have already committed (and hence "forward" in time). If writer txns 
notify readers before writers' write phase if its write set overlaps with readers' read sets, then it is Backward OCC (BOCC).

(TODO: Concrete impl. of validation for BOCC and FOCC, using versions, global counter, broadcast)

### Fine Grained Conflict Inference

(TODO: Talk about the degree of parallelism of read validation)

{% highlight C %}
 Txn 1               Txn 2
Read  A      
                    Read  B
                    Write A
                    Commit
Read  B
Write C
Commit
{% endhighlight %}

(To be finished)

### References

[1] Herlihy, Maurice, and J. Eliot B. Moss. **Transactional memory: Architectural support for lock-free data structures.** Vol. 21, no. 2. ACM, 1993.

[2] Rajwar, Ravi, Maurice Herlihy, and Konrad Lai. "**Virtualizing transactional memory.**" In Computer Architecture, 2005. ISCA'05. Proceedings. 32nd International Symposium on, pp. 494-505. IEEE, 2005.

[3] Ananian, C. Scott, Krste Asanovic, Bradley C. Kuszmaul, Charles E. Leiserson, and Sean Lie. "**Unbounded transactional memory.**" In High-Performance Computer Architecture, 2005. HPCA-11. 11th International Symposium on, pp. 316-327. IEEE, 2005.

[4] Litz, Heiner, David Cheriton, Amin Firoozshahian, Omid Azizi, and John P. Stevenson. "**SI-TM: reducing transactional memory abort rates through snapshot isolation.**" ACM SIGARCH Computer Architecture News 42, no. 1 (2014): 383-398.

[5] Kung, Hsiang-Tsung, and John T. Robinson. "**On optimistic methods for concurrency control.**" ACM Transactions on Database Systems (TODS) 6, no. 2 (1981): 213-226.

[6] Rajwar, Ravi, Maurice Herlihy, and Konrad Lai. "**Virtualizing transactional memory.**" In Computer Architecture, 2005. ISCA'05. Proceedings. 32nd International Symposium on, pp. 494-505. IEEE, 2005.

[7] Ceze, Luis, James Tuck, Josep Torrellas, and Calin Cascaval. "**Bulk disambiguation of speculative threads in multiprocessors.**" In ACM SIGARCH Computer Architecture News, vol. 34, no. 2, pp. 227-238. IEEE Computer Society, 2006.

[8] Moore, Kevin E., Jayaram Bobba, Michelle J. Moravan, Mark D. Hill, and David A. Wood. "**LogTM: log-based transactional memory.**" In HPCA, vol. 6, pp. 254-265. 2006.

[9] Minh, Chi Cao, Martin Trautmann, JaeWoong Chung, Austen McDonald, Nathan Bronson, Jared Casper, Christos Kozyrakis, and Kunle Olukotun. "**An effective hybrid transactional memory system with strong isolation guarantees.**" In ACM SIGARCH Computer Architecture News, vol. 35, no. 2, pp. 69-80. ACM, 2007.