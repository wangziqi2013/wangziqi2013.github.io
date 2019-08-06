---
layout: paper-summary
title:  "Filter Caching for Free: The Untapped Potential for Store Buffer"
date:   2019-08-05 16:51:00 -0500
categories: paper
paper_title: "Filter Caching for Free: The Untapped Potential for Store Buffer"
paper_link: https://dl.acm.org/citation.cfm?doid=3307650.3322269
paper_keyword: Store Buffer; Filter Cache
paper_year: ISCA 2019
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes using the store buffer as a small fully-associative cache to achieve less energy consumption and shorter load 
latency on modern architectures. Virtually all processors nowadays are equipped with a store buffer to hide the relatively 
slower coherence protocol. Without a store buffer, store instructions that are ready to commit otherwise must wait for the cache 
controller to acquire ownership of the cache block before the block can be updated. In a multi-chip architecture, this may 
take several hundreds of cycles in the worst case, which poses a great performance disadvantage as processors will stall and 
wait during this time.

To ensure the illustion of ordered execution, processors need to check not only the L1 cache, but also the store buffer, 
when a load instruction is executed. If a committed store with the same address as the load is found in the store buffer,
the processor either defers the commit of the load until the store is written into L1 (load-bypassing), or directly forwards 
dirty data just written by the store from the store buffer to the load instruction (load-forwarding). Note that although the 
store buffer plays an important role in the memory consistency model of the processor, whether or not loads are forwarded 
from stores do not affect the consistency model. For Sequential Consistency, load instructions must not commit before 
stores before it in the program order, i.e. they remain speculative in the load queue. When there is no aliasing in the 
store buffer, the coherence request is either made only after the store is committed, or speculatively made when the load is executed, 
and is squashed and replayed if the cache block is invalidated by coherence. If there is a conflict in the store buffer,
no matter whether load bypassing or forwarding is used, the load instruction must also remain speculative, and can only
commit after the store does. In Total Store Ordering (TSO) such as x86/x86-64, data is always forwarded from the store 
buffer, if there is aliasing (if not then directly access the cache and commit). Load instructions commit as soon as data 
is ready without waiting for preceding stores, essentially ordering themselves before stores in the program order. 
Stores are always written into the cache from the end of the store buffer, maintaining the store-store program order.

As indicated above, for the sake of correctness, it is crucial that the store buffer be checked every time a load is issued 
by the pipeline. It is, however, also observed by the authors that the actual hit rate is very low (~8% on SPEC in average).
The low hit rate of store buffer justifies the design choice of probing both the buffer and L1 cache in parallel, which 
has been adopted by most processors (by contrast, processors never probe L1 and L2 cache in parallel, because the L1 
cache alone often has a high hit rate). Whether or not the load request hits the store buffer, we always have to pay
the energy and port contention for a fully associative probing into the buffer CAM.

The paper therefore points out that, by treating the store buffer as a small, fully associative filter cache, we may 
achieve higher hit rate without fundamentally changing the functionality of the store buffer. On an ordinaly design,
the store buffer is emptied as quickly as possible, usually right after the L1 is able to accept a new request, since 
the store buffer usually also shares storage with the store queue (because they both require fully associative lookup
and serves similar purposes). If the store buffer remains full for an extended period of time, structural hazard may happen, 
which stalls the processor by preventing new store instructions from being inserted (typical store buffer/queue has 56
entries). 

The technique proposed by this paper is described as follows. When a store operation commits, it is added into the store
buffer, and written back to the L1 cache as soon as possible. Instead of clearing the store buffer entry when the data
is written out, the processor retains the entry in the buffer, unless a new entry is to be allocated for a new store instruction,
and there is no space left. By retaining entries that have already been written out to the L1 in the store buffer, 
the hit rate of the store buffer increases to ~18% on the same benchmark, a 23% improvement. To avoid accessing stale 
data when the cache block is invalidated by coherence after writing back the store buffer entry, the entry whose block
was invalidated should also be invalidated and removed from the store buffer. This poses another challenge in the design.
First, simplying removing the entry would complicate resource allocation, as entries in the store buffer are no longer
consecutive. Second, in normal cases, coherence messages stop propagating at L1. Adding the store buffer as a filter cache
implies that the invalidation should further propagate to the store buffer for every invalidation. This not only adds extra 
traffic and port contention for the store buffer, but also consumes energy, because every invalidation requires a fully
associative lookup. On the other extreme, on every invalidation of any block in L1, a signal is sent to the store buffer,
which invalidates all "completed" entries. Although this scheme is much simpler and only requires a bulk invalidation
(which does not need a CAM lookup-by-address opration), it severely reduces the hit rate, since the store buffer will be 
flushed even if the invalidated block does not exist in the buffer. 

As a midpoint, the paper proposes using epoches to identify whether a block is in the store buffer or not, with false
positives but never false negative. The store buffer maintains an "epoch counter", which is incremented by one every time
it is invalidated. When the epoch counter changes, we know that blocks that are written back to L1 in an older epoch can 
never be in the store buffer. The tag array of L1 is extended with an array of epoches. On every L1 write, in addition to 
setting the "dirty" bit in the tag, we also set the epoch of the cache line as the current epoch in the store buffer. 
When an L1 block is invalidated or evicted, the epoch is also sent to the store buffer. The store buffer compares its local
epoch with the signal, and if they differ, no invalidation will happen, since we know that the invalidation or eviction
is conducted on a line that is no longer in the buffer. Compared with the simple scheme, no associative lookup is performed, but 
instead we just need an integer equality comparator (essentially an array of XOR gates). In practice, using an infinite 
or even a reasonably large number of counters are unrealistic due to the strict requirement on L1 latency and area.
As a approximation, we allow the epoch counter to wrap back when it overflows, which causes no harm, because this only
introduces false positives, but never false negative (i.e. we do not stale data to be accessed from the store buffer).
In fact, the paper proposes using only 1-bit counter, i.e. a second "dirty" bit in L1 tags. These two dirty bits could 
support 3 counter values in total (epoch zero means the block is clean, which cannot be used since this has its own meaning).
Evaluation shows that three epoches is sufficient to filter out most irrelevant block invalidations with low overhead.

