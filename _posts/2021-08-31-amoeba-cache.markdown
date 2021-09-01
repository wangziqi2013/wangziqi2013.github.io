---
layout: paper-summary
title:  "Amoeba-Cache: Adaptive Blocks for Eliminating Waste in the Memory Hierarchy"
date:   2021-08-31 23:46:00 -0500
categories: paper
paper_title: "Amoeba-Cache: Adaptive Blocks for Eliminating Waste in the Memory Hierarchy"
paper_link: https://dl.acm.org/doi/10.1109/MICRO.2012.42
paper_keyword: Amoeba-Cache; Tag-less Cache
paper_year: MICRO 2012
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Comments:**

1. I would say Sec 2.2 and Figure 3 have presentation issues, and both are misleading. 
   In Sec 2.2 and Figure 3, however, the author seems to suggests that there is a trade-off between bandwidth and 
   miss rate, which is not the case. The problem is that both bandwidth and miss rate are
   simply just derived quantities of locality and the block size.
   The motivation of this paper is that access locality varies greatly among applications, and 
   different access locality favors different block sizes, so it is important to be able to support
   different block sizes.
   So why you did not show the relation between (locality plus block size) and (miss rate plus bandwidth), but 
   just ignore locality (i.e., application name since it is intrinsic to the application) and show a trade-off
   between miss range and bandwidth?
   

This paper proposes Amoeba Cache, a tag-less cache architecture that supports multiple block sizes.
The paper is motivated by the fact that in conventional caches, it is often the case that spatial locality within a 
block is low, such that the block is underutilized during its lifecycle between fetch and eviction.
This phenomenon wastes bus bandwidth, since most of the contents being transferred on the bus and stored in the data 
array will be unused.
Amoeba cache addresses this issue by enabling variable-sized blocks and variable associativity per set.
Blocks having low utilization can thus only be partially cached to avoid paying the overhead of transfer and 
storage for no performance benefit.

The paper begins by observing the relation between access locality and block size in a conventional, fixed block size
cache. The paper suggests that larger blocks favor high access locality, since data fetched into the cache will likely 
be accessed by future memory operations, which reduces average memory access latency. In addition, the bandwidth 
overhead of transferring the block to the cache is also amortized across the many operations that hit the cache, which
helps reducing overall bus contention.
If the access locality is low, however, then most of the contents fetched into the cache will not be used,
resulting in under-utilized blocks, which wastes cache storage as well as bus bandwidth.
Small cache blocks, on the other hand, favors low locality access, as the storage and bandwidth overhead will be small
per cache miss.

The paper then concludes that it is difficult to determine a static block size that is optimal for all workloads,
since different workloads have significantly different access patterns and performance traits.
The paper defines the utilization of cache blocks as the percentage of 64-bit words that are actually used during
the lifetime of the block (from fetch to eviction) in the L1 cache over the block size in the number of words.
Experiments show that, the optimal block size for different applications vary greatly, ranging from 32 bytes to 256
bytes. Even within the same application, the access locality and hence optimal block size will change at different
stages of execution. It is therefore impossible to achieve optimal block size for all applications, which highlights
the importance of supporting variable sized blocks.
