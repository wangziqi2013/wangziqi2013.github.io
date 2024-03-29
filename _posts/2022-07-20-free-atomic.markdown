---
layout: paper-summary
title:  "Free Atomics: Hardware Atomic Operations without Fences"
date:   2022-07-20 03:56:00 -0500
categories: paper
paper_title: "Free Atomics: Hardware Atomic Operations without Fences"
paper_link: https://dl.acm.org/doi/10.1145/3470496.3527385
paper_keyword: Load Queue; Store Queue; Atomics; Memory Consistency
paper_year: ISCA 2022
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. x86 inserts two implicit barriers to atomic operations. One before it to ensure that all memory operations are 
committed and drained before the load uop issues, and another after it to ensure that no load operation can issue
before the store uop drains.

2. The main purpose of the two barriers is to prevent deadlock, simplify store-load forwarding, and simplify load
speculation of atomic operations. The paper argues that with proper handling of these three issues, removing the
barriers will cause neither consistency order violation nor atomicity violation.

3. The paper relaxes the memory ordering requirements of atomic operations, which allows these operations to
speculate and be ordered (in a limited but rather relaxed fashion) with other memory operations, or even operations
from other atomics.

**Comments:**

1. I am not very sure about the baseline system's implementation of load speculation. Does the author assume 
load-load reordering during speculation? From the text it appears that loads can speculate freely without 
obeying program order. But since TSO disallows load-load reordering from a consistency point of view, this 
requires some extra mechanism (e.g., implementing speculative loads like HTM transactions) that is not
described in the paper.

2. Does the Free Atomic design still only commit the unlocking store uop when the store buffer is free?
It would appear so from the text, but this is not mentioned anywhere as part of the design. 

This paper proposes Free Atomics, a microarchitecture optimization aiming at reducing memory barrier cost of atomic 
operations.
The paper is motivated by the overhead incurred by the two implicit memory barriers surrounding x86 atomic operations.
The paper proposes removing these two barriers, allowing the load-store pair belonging to the atomic operation
to freely speculate and be reordered with regular memory operations, thus reducing the overhead.
However, without care, anomalies such as deadlocks, livelocks, and store-load forwarding may also occur after
removing the barriers, due to more complicated cases of memory access reordering.
These anomalies are addressed with either operation timeouts, or an extra hardware structure that tracks 
the ongoing status of atomic operations. 

The paper assumes a baseline implementation of atomic operations on x86 platforms that we describe as follows.
The baseline processor implements out-of-order execution with separate load and store queues. The memory consistency
model is Total Store Ordering (TSO), meaning that store-load sequence in program can be reordered as long as the 
store and load are to non-overlapping addresses, while load-load, store-store, and load-store are not reordered.
Atomic operations, consisting of a load, arithmetic, and store, are performed in an atomic manner, such that no 
other store operation may occur in-between the load and the store in the global memory consistency ordering 
(the paper explains, in later sections, that this is a type I atomic operation).
The atomic operation is decoded into several uops: a load, a store, and one or more ALUs uops.
In addition, two implicit barriers are added. The first barrier is inserted before the load uop, which prevents it
from being issued, until all earlier memory uops have successfully committed.
This barrier serves two purposes. First, it avoids executing the load uop in a speculative manner, such that the load
will not be rolled back after it has been handled by the cache. 
Second, the barrier also prevents earlier loads from being reordered with the atomic operation's load and store. 
This may create complicated race condition that results in deadlock or livelock with another core performing atomic 
operation.

The second barrier is inserted after the store uop, such that no later load uop will be issued until the store uop
is fully drained from the store buffer (i.e., becomes globally visible). 
Note that since the first barrier already drains the store buffer, and that the load uop will acquire the target
block and lock it in the L1 cache, the store uop can always be instantly written into the cache in this case
after the atomic operation commits in the ROB (and hence, it is equivalent to saying that the second barrier 
actually only blocks the load until the atomic operation commits, as the paper does).
A side effect of the two barriers is that earlier stores and later loads will not cross the atomic operation.

When being handled by the cache hierarchy, the load uop of the atomic operation will acquire the cache block
in write-exclusive mode, and then locks the block in the cache. Locking is typically implemented as a single register
storing the address being locked.
A single locked address design suffices for the baseline system, since atomic operations are always executed 
non-speculatively, and in isolation from other instructions.
External requests for the locked address, such that coherence invalidations, downgrades, and evictions, will
be denied, until the block is unlocked.
The block is unlocked when the store uop is handled by the cache (not when it is committed!).
block is unlocked.

This paper observes that, under certain conditions, these two barriers can be removed, which unleashes more 
instruction level parallelism.
The first condition is to allow speculative execution of the load uop.
One complication is that, if the load uop can be speculatively executed, then it may also be squashed on a 
mis-speculation. This requires the system to be able to unlock a block when the load uop that originally locks
it is squashed.
In addition, since multiple lock uops can be speculated, the system must also keep track of potentially
several locked addresses.
Assuming that the above requirements are met, then when a mis-speculation happens, as load uop is rolled back,
the processor will also unlock the cache block being locked by the load uop using the address of the uop. 

Another complication that can occur is store-load forwarding. There are several subcases.
First, when an atomic load uop forwards from a non-atomic store, the load uop is logically performed
atomically as the store uop. In this case, the processor should lock the cache block as soon as the 
store uop brings the block into the local L1 cache, because otherwise, an interleaving store from a remote core 
would break atomicity.
Second, when an atomic load forwards from an atomic store (note that this is now possible since the pipeline
may have several speculative atomic operations), the store does not need to unlock the cache block, because, 
based on the same reason above, the load is logically conducted atomically with the store, and in this case,
the two atomic operations are essentially soldered into one big atomic operation.
The paper claims that this is actually good for locality, because atomic operations that are close to each
other are likely merged as one big atomic operation, which avoids any intermediate coherence invalidation.
This, however, can also potentially turn into starvation, where one processor keeps issuing atomic operations
on the same cache block, gets forwarded infinitely, and blocks the address from being accessed by other cores.
To prevent this pathological case, the paper suggests that the maximum number of forwarding should be limited
(e.g., to 16).
The last case is memory forwarding from atomic store to non-atomic load. This case does not require any special
attention, and just works as usual.

The next complication is deadlock, which occurs when two processors request an address from each other, while
each holding a locked block in their private L1 cache, the address of which is being locked in the other.
This case will not occur in the baseline system, because no other memory uop will be between the load uop for
locking and the store uop for unlocking. 
With the removal of the fence, however, an earlier store may be handled by the cache, after the locking load uop
is. In this case, since uops are drained from the store buffer in-order, the intermediate store uop will block
the following unlocking store uop from draining, which further prevents itself from being serviced, as the 
address is locked in another processor.
Another case of deadlock occurs when a later load speculates in-between the locking load and the unlocking store.
The intermediate load uop will be unable to commit, which also blocks the commit of the unlocking store uop,
since uops are committed in-order.

The paper also studies a third scenario introduced by cache line invalidation to enforce inclusion. 
The deadlock mechanism is roughly the same, except that deadlock occurs because one intermediate memory
operation on one core causes the lower level cache to evict a block locked in another processor.
The eviction, however, will be denied since a locked cache block must be retained in the L1 cache until
the unlocking store uop drains. If this occurs symmetrically on two processors, then deadlock
will arise. Even worse, since the deadlock can only be detected by the lower level directory, the L1
cache does not even know that the deadlock is formed.

To address all three scenarios of deadlocks with a simple mechanism, the paper proposes using a watchdog timer
to monitor the time it takes between a locking load uop and an unlocking store uop.
If the atomic operation takes too long to finish, then the watchdog timer will fire, which causes the pipeline to
flush all uops since the oldest atomic operation, and reexecute. 
This resolves the deadlock and ensures that global progress is always made, since after one processor flushes its
pipeline hence releasing the locked block, the other processor can make progress. 

The paper also argues that atomicity is not harmed if the atomic operation can freely reorder with other memory
operations as if they were just regular memory operation. 
First, earlier loads reordering with the locking load uop will not affect atomicity, because loads do not change
system state. The same reasoning applies with later loads reordering with the unlocking store uop.
Second, earlier stores that reorder with the locking load may appear to be problematic, since it modifies the 
contents of the locked block. However, with more careful reasoning, the store, if it overlaps with the 
loading load uop, then the load uop will be forwarded from the store uop, in which case the store uop
is logically atomic with the load, as we have explained earlier.

However, the above analysis is still missing one case, where a later load reorders with both the load and the store 
of the atomic operation, and also reorders with an earlier store. This is disallowed, since the atomic operation
itself is also semantically a barrier that no memory operation may be reordered with (this is different from reordering
with individual load or store of the atomic).
**I did not quite understand the analysis presented in the paper**, because the paper repeated says
"committing a Free atomic only when the SB is empty.". I thought this is the case for baseline system, but the 
paragraphs in Section 3.2.3 discuss the Free Atomic design where stores are free to be committed while all other 
stores are still in the store buffer.

To implement the above design points, the paper proposes adding an Atomic Queue (AQ) to the L1 cache as a 
tracking structure for outstanding atomic operations. 
The AQ tracks the locking status of the cache block accessed by the atomic operation as a 1-bit locked flag, 
the cache set and way of the block, 
the store queue entry, if the locking load uop is forwarded from an earlier store,
and the ROB serial number for flushing the atomic operation when the watchdog fires.
The locked bit is set when a locking load uop brings the cache block into the local L1 cache.
The set and way of the locked block is also set to the physical location of the block as well.
The locked bit is cleared when the unlocking store uop is handled by the L1 cache (note that this is
after the atomic operation is committed). 
When external coherence or invalidation requests arrived, they are looked up in the AQ. If the requested block
is currently locked, the request is denied.
When the local L1 cache is to evict a block, the set number is also used to search the AQ. Locked lines will not
be evicted by the replacement protocol (assuming that the number of AQ entries is fewer than L1 ways, such that
a victim can always be found) in order to maintain the locked status. 

The AQ also handles store-load forwarding. When a store forwards value to a locking load uop, the store's entry index
in the store buffer is saved in the AQ (or, when it leaves store queue and enter store buffer). 
When the store uop is drained from the store buffer, if the entry is saved in one of the AQ entries, the cache block
accessed by the store uop will be locked, and the locked bit, the set and way index of the corresponding AQ entry
will be updated.
This mechanism works for both regular stores and unlocking store uops, because in both cases, the cache block
to be accessed by the store will remain locked after the store is handled by the cache.
