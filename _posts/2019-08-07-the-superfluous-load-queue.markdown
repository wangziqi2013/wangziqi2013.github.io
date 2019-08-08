---
layout: paper-summary
title:  "The Superfluous Load Queue"
date:   2019-08-07 17:18:00 -0500
categories: paper
paper_title: "The Superfluous Load Queue"
paper_link: https://ieeexplore.ieee.org/document/8574534
paper_keyword: Load Queue; Speculative Execution; TSO
paper_year: ISCA 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Load queue has long been used in microarchitectures as one of the many hardware structures that support speculation.
When a load instruction is inserted into the reordered buffer (ROB), an entry is also allocated in the load queue
which contains full information of the instruction just as in the ROB. Load instructions are inserted into the load
queue in the program order (because the front end inserts into the ROB in the program order). During the execution, three
conditions are checked to ensure both correct program semantics and memory consistency guarantees. First, to maintain
the illustration that instructions are executed one by one in the program order, load instructions should always 
read the most recent value written by the same processor if there is no remote store. The store instruction, however,
may still be in the pipeline (and also store queue) and has not been committed; or even if it has been committed, it may 
stay in the store buffer for a while just to wait for L1 to acquire line ownership. It is therefore insufficient simply 
let the load instruction check the L1 cache. In fact, all these three structures should be checked, and whether the 
load is allowed to continue execution depends on the result of the checking. If there is an older store instruction in 
the store queue, and its address has not yet been fully calculated, there is no way for the load to forward or bypass 
the store. In most designs, the load instruction will simply assume that the older store does not conflict with itself,
and then proceed. In the (relatively) rare case that a conflict truly happens, this leads to incorrect result, because 
the value returned from the load instruction is not the most recent store. To counter this, after a store instruction commits
(or after the store resolves its address), it searches the load queue for a younger load whose address conflicts with
the store address. If such a load exists, it implies that the load incorrectly speculated over a store-load dependency,
and should be squashed in the pipeline. 

The second case where a load queue is useful is when a load is executed out-of-order with regard to other loads and/or
stores. Whether or not this reordering is allowed to be exposed depends on the memory order specification. In Sequential
Consistency (SC) model, no reordering of loads and stores are allowed to be observed by an external viewer, although
the actual implementation can still reorder some of them, as long as it can guarantee that no external viewer can 
see them. In such a consistency model, the pipeline maintains the illustration that every instruction "takes effect"
at the commit point. Load operations, however, are always executed as soon as its operands are ready, because of the 
relatively long latency of loads compared with ALU instructions. If the SC implementation eagerly isses load requests (to
the L1 cache), the load queue will be responsible for maintaining SC semantics: every time a cache line is invalidated 
by a remote store, or evicted from L1 (no longer be able to receive invalidation notification), the load queue is searched 
using the cache line address. If a speculative load conflicts with the address, it should be squashed, because an external
writter may observe wrong ordering on the same block (the load is ordered before the remote store, but according to SC, 
it should be ordered after the remote store). 

For a more relaxed consistency model such as Total Store Ordering (TSO), where store-load reordering is allowed, the load
queue is still a crucial part of the microrchitecture for enforcing load-load ordering, which is not allowed. Recall that
in TSO, while loads could legitimately bypass an earlier store by not checking for interleaving stores between the L1
read request and the actual commit, loads must still maintain the illusion that they are committed in-order. This 
translates to the following ordering requirement: for any two loads l1 and l2, if l1 is before l2 in the program order,
then for any remote store s1, if l2 does not see the updated data of s1, then neither does l1 (because otherwise, l1 is 
ordered after the store by observing its updates, while l2 is ordered before s1, which is equivalent to load reordering). 
To enforce load-load ordering, if instruction l2 is issued before l1, then it must be the case that no interleaving store
happens between the cache read request of l2 and that of l1. This implies that, if a cache line invalidation or eviction
happens between l2 and l1's read request, then l2 must be squashed, because the data it has read is no longer valid under
TSO. If a load instruction bypasses multiple loads, similar rule applies that no invalidation or eviction is allowed until
all of the bypassed loads read the L1 cache. In practice, processors often extend this "vulunerability window" to instruction 
commit time, such that load instructions appear to be executed at the exact time that they commit.

Prior papers have proposed load queue-less designs by using value-based validation. Instead of letting the load queue know
that an interleaving store operation or eviction invalidated a speculative load, the processor only checks the validity of 
the loaded value at commit time. This check is performed by re-reading the same cache block at commit time, and comparing the 
current value with the old value. If these two values differ, then some writes must have already updated the cache block,
resulting in a squash. Otherwise, it is also possible that some stores updated the block, but since the two values coincide,
the (potentially illegal) execution still have the same effect as a legal execution.

As this paper pointed out, both invalidation-based and validation-based design have flaws that cost extra area and energy 
for no good. In invalidation-based (i.e. with a load queue) design, the load queue is implemented as a Content-Addressable 
Memory (CAM), which also has multiple read ports for parallel lookup. CAMs are expensive on hardware to implement, and are
power-hungry. In addition, it is difficult to scale CAMs, because their complexity grows exponentially with their sizes.
In validation-based design, no CAM area and search overhead is paid, because we can get rid of the load queue entirely.
It is, however, required that the L1 be accessed twice for each load instruction: first when the load is issued,
and the second when the load finally commits. The extra L1 access can be expensive, because an extra read port is needed
to avoid port contention, and also L1 access is also a (smaller) associative lookup.

This paper proposes not using a load queue as in validation-based design, but also without re-reading L1 for value-validation. 
The insight is that, instead of using a dedicated load queue, and let other components perform associative lookup when some 
loads are susceptible to squashes, we can simply mark the suspicious instruction or cache block (e.g. stores whose addresses
have not been calculated) with a "sentinel", and delay the writing/invalidation/eviction of them to avoid introducing 
unrecoverable ordering violation until the load is ready to commit, at which time value-validation is performed.