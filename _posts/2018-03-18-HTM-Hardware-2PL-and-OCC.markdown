---
layout: post
title:  "Hardware Transactional Memory: Hardware Two Phase Locking and Optimistic Concurrency Control"
date:   2018-03-09 03:32:00 -0500
---

Hardware transactional memory (HTM) eases parallel programming through built-in support for 
transactional semantics directly on the hardware level. Concurrency control (CC) is a family of implementation 
independent algorithms that achieve transactional semantics by the scheduling of state-dependent operations. 
In the discussion that follows, we focus on a page based model where only reads and writes are state-dependent.
Several software implemented CC mechanisms are already deployed in applications such as database management systems,
including Two Phase Locking (2PL), Optimistic CC (OCC), and Multiversion CC (MVCC). In this literature, we 
explore the design space of CC algorithms in hardware. We first review a few hardware features that can serve as
build blocks for our CC algorithm. Then based on these hardware features, we incrementally build an HTM 
that provides correct transactional semantics, with increased degrees of parallelism. We only cover
2PL and OCC here, as they share some characteristics that can simplify the explanation. 
MVCC will be discussed in a different literature.

In a multiprocessor system, to ensure coherence of cached data while allowing every processor to manipulate data in its private L1 cache, 
hardware already implements a multi-reader, single-writer locking protocol for each individual cache line, dubbed "cache coherence 
protocol". We use MSI as an example. When a cache line is to be read by the cache controller, the controller sends a read-shared message 
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

If we treat "S" state as holding a read lock on a cache line, and "M" state as holding an exclusive write lock, then the MSI 
protocol is exactly a hardware implementation of preemptive reader/writer locking. Compared with software reader/writer locking,
instead of the requestor of a conflicting lock mode waiting for the current owner to release the lock, which may incur deadlock and 
will waste cycles, the hardware choose not to wait, but just to cooperatively preempt. Here the word "cooperatively" means the 
current owner of the lock is aware of the preemption via the cache coherence message. As we shall see later, the cooperative 
nature of hardware preemption helps in designing an efficient protocol.

Since preemptive reader/writer locking is already implemented on the heardware level via cache coherence, it should not be too
diffcult to implement two phase locking (2PL) on top of this. Indeed, what 2PL requires is simple: (s1) All read/write operations
to data items should be protected by locks of the corresponding mode; (s2) No locks shall be released before the last acquire of
a lock, thus dividing the entire execution into a grow phase, where locks are only acquired, and a shrink phase, where locks are only
released. It is also correct to make (s2) more restrictive: (s2') Locks are acquired 
as we access data items, but no locks shall be released before the final commit point. (s1)(s2) is the general form of 2PL, 
granting the full scheduling power of the 2PL family, while (s1)(s2') is called strong strict 2PL, or SS2PL. There is actually a midpoint,
(s2'') Locks are acquired as we access data items, and no **writer** locks shall be released before final commit point. Reader locks 
shall not be released before the last lock acquire as in 2PL. (s1)(s2'') is called strict 2PL, or S2PL.

Translating the above 2PL principle into hardware terminologies, we obtain the following principle for hardware transactions: 
(h1) All transactional load/store instructions must use cache coherence protocol to obtain permission to the cache line
under the corresponding state; (h2) Before acquiring the last cache line used by the transaction, no cache line shall be
evicted by the cache controller, either because of capacity/conflict misses, or because some other processors intend to 
invalidate the line.

(TODO: How to implement SS2PL/S2PL/2PL in hardware)

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