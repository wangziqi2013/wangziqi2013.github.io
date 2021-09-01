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

**Highlights:**

1. Optimal block size of a cache depends on access locality of applications currently running on the cache. 
   Different applications demonstrate different locality traits, and therefore it helps to achieve optimal 
   performance by supporting different block sizes within the same cache.

2. Variable sized blocks can be supported by adding a range descriptor in addition to the conventional 
   address tag which is essentially just a pair of 
   delimiters describing the start and end offset of the block within a larger unit (a "region" in this paper).

3. Variable associativity can be supported by embedding tags in the data store and using a bit map to indicate
   which words store tags. The separate tag array can be get rid of this way. The lookup circuit just reads all
   of the data array of the set and recovers the tags according to the bitmap.

4. Both 2 and 3 described above can also be used for compressed caches, which is just another form of variable 
   block size and variable associativity. This paper is actually another form of cache compression: Instead of
   using encoding methods to reduce the size of a full block, the Amoeba cache leverages the sparsity of data
   and simply does not store words that are predicted not used.

5. The same analogy in the above point also applies to LCP (Linearly Compressed Pages) and Page Overlays, 
   in which the former relies on encoding of individual cache lines, while the latter relies on certain lines 
   not being present in a page to reduce storage.

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

Amoeba cache addresses the above issue by enabling variable sized blocks and variable associativity per cache set.
There are a few challenges. 
First, the data store must be able to be addressed in a more fine-grained manner, unlike a conventional cache where 
blocks can only start at fixed offsets given the way number. 
In Amoeba cache, data blocks can potentially start at arbitrary offsets, which requires extra addressing in addition 
to the way number.
Second, there is no longer a fixed number of tags per set, due to the fact that smaller blocks enable larger
associativity as more blocks can be stored in each set, each needing a tag entry to describe data.
A fix sized tag array will not work in this case for obvious reasons.
Lastly, the cache should predict which words in which blocks are likely to be used, such that only these words are 
fetched into the cache to save storage and bandwidth. 
The prediction is performed per cache miss before the fetch request is sent to lower levels. 

The overall architecture of Amoeba cache is described as follows. 
Amoeba cache stores partial blocks as a consecutive range of 64-bit words in a larger unit called a "region", which is
aligned 64-byte blocks in this paper (i.e., identical to conventional cache blocks). 
To simplify encoding, a partial block must be fully contained in a region, and must be a consecutive range.
Each partial block is described by a tag entry, which consists of the address tag of the region that contains it
(i.e., the conventional address tag), a start and end word offset, and other metadata bits.
Amoeba cache entirely gets rid of the tag array by storing tag entries inline with data in the data array.
The layout of the data store is described by a tag bitmap (T? bitmap), in which a bit represents a word in the 
data array, and a bit is set if the corresponding word contains the tag entry (the paper assumes that a tag
entry can be stored in a 64-bit word, which is likely true for most implementations).
Data immediately follows the tag entry, such that no extra pointer for data is needed.
To aid block insertion, the paper also proposes adding an extra valid bitmap (V? bitmap), in which each bit represents
whether a word is occupied for either tag or data. The cache controller should search for unused space by 
consulting the valid bitmap on insertion, and update the bitmap accordingly after insertion or eviction.

On a lookup operation, the set index is computed using the address of the region of the requested address.
This guarantees that all partial blocks belonging to the same regions are mapped to the same set, which simplifies
lookup, since operations that span multiple partial blocks can be satisfied with one single set lookup.
The entire set is read out by accessing the data bank, after which all tags are located using the tag bitmap.
The lookup logic then performs tag check by comparing the region tag against the requested address, as well as
comparing the requested offset with offsets of the partial blocks. If the request can be satisfied, indicated by
the fact that all requested words are currently cached by partial blocks, data is read out by combining the requested 
words from potentially multiple partial blocks.

On an access miss (could be a partial miss, if a request can only be partially fulfilled by the cached content),
the cache controller performs a prediction of the range to be fetched using a locality predictor (discussed later),
and sends the request to the lower level with the range to be fetched. 
To simplify coherence, the requested range is a consecutive range of words that are predicted to be useful, with 
possible overlapped with existing ranges of the same region (if the overlap happens at the boundaries, then 
the requested range can be smaller by removing the overlapped range). 
After the fetch request is fulfilled by the lower level, the cache controller inserts the new partial block into 
the data array by either merging the new block with an existing block, if they happen to be adjacent to each
other in the region, or just insert it as a new block with a separate tag entry.
In both cases, the controller needs to search for free space using the valid bitmap, and perform de-fragmentation
to avoid excessive external fragmentation, if necessary.

