---
layout: paper-summary
title:  "The V-Way Cache: Demand-Based Associativity via Global Replacement"
date:   2018-06-18 22:57:00 -0500
categories: paper
paper_title: "The V-Way Cache: Demand-Based Associativity via Global Replacement"
paper_link: https://ieeexplore.ieee.org/document/1431585/
paper_keyword: LLC; V-Way Cache; Global Replacement
paper_year: ISCA 2005
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Fully associative cache has the least number of cache misses and hence the 
best performance when compared with a set-associative cache of the same size. Two factors
contribute to the superiority of full associativity. First, a fully associative cache do not 
force a cache eviction as long as the cache has not been filled up yet. This reduces the 
number of conflict misses. On the contrary, evictions are mandatory for a set-associative cache if all cache lines
in a set has been occupied, regardless of whether empty lines exist in other sets. Second, even if the 
cache is full, a fully associative cache can evict any of the lines currently in the cache, maximizing the 
possibility that a "bad" line which does not benefit from extra locality is evicted. For a set-associative 
cache, however, an eviction must be made within the set that the missed line will be loaded. Given that the 
number of ways in a typical cache is usually significantly smaller than the total number of lines, it is likely 
that the decision is sub-optimal. In the following discussion, eviction decisions made by considering all lines 
in the cache is called "global replacement", while decisions made only within a certain set is called "local replacement".

Increasing the associativity of a cache or simply using fully associative cache, according to the results reported 
by the paper, can increase the hit rate. The extra cost and hardware changes, however, may not justify the performance
improvement. One problem with large associativity is the cost of extra data store, as the number of tags in each
way must equal the number of blocks allocated to that way. Furthermore, the latency of tag comparison, which is on
the critical path of memory instructions, increases as the number of tags to compare increase. Power consumption
and heat dissipation can also be problematic with large tag array.

This paper prposes Vraiable-Way (V-Way) Cache, which is a middlepoint between the classical set-associative cache and fully
associative cache. The trade-off between associativity and hardware cost is made such that the number of tags in 
each set is doubled, while the total number of blocks in data store remains unchanged. The mapping between tags and 
data store blocks are not statically determined as in the current cache design. Instead, tags are assigned a cache 
block dynamically only when the tag is allocated. The assigned block is selected from a global pool of free blocks. 
Eviction decisions are made based on global replacement algorithm, which maximizes the opportunity that a "bad" block 
is evicted. We describe the operations in detail in the next few sections.

Prior work focuses on increasing the associativity of L1 cache dynamically by using a small and fully associative
cache called the "Victim Cache". Blocks evicted from the L1 cache is stored in the victim cache. On memory operations,
both the L1 cache and the victim cache is searched. If the L1 cache misses but there is a hit in the victim cache, then
the victim block is reloaded into L1, avoiding a relatively expensive search operation in the next level cache. 
Although the original victim cache is designed for direct-mapped L1 cache to prevent cache thrashing while more 
than one stream that are mapped to the same set are being accessed simultaneously, the idea could be generalized 
to set-associative caches easily. The V-Way design differs from victim cache in the following aspects. First,
V-Way cache is designed for lower level caches (i.e. closer to the main memory) rather than L1. This is because 
some design decisions slightly hurt the hit latency and reduces hardware parallelism during a cache lookup. This 
can be fatal for L1, but is fine for L2 and LLC. Second, the V-Way cache also changes cache replacement policy,
which gives it an advantage over victim cache, which has little do to with the replcement policy. 

As mentioned above, the V-Way cache provides elastic associativity without adding extra data store via 
decoupled tag and data store. Tags are not mapped to cache blocks statically. Instead, each tag is extended with
a pointer, called the Forware Pointer (FPTR), which points to the cache block is it assigned if the valid bit
is set. Similarly, each data block has a Reversed Pointer (RPTR), which points to the tag the block is allocated
to if the block holds valid data. In all cases, FPTR and RPTR should point to each other.