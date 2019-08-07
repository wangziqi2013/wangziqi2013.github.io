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