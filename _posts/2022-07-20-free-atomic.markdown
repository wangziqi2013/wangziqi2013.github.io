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
