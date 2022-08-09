---
layout: paper-summary
title:  "The reuse cache: downsizing the shared last-level cache"
date:   2022-08-09 01:13:00 -0500
categories: paper
paper_title: "The reuse cache: downsizing the shared last-level cache"
paper_link: https://dl.acm.org/doi/10.1145/2540708.2540735
paper_keyword: Reuse Cache; RRIP; Decoupled Tag-Data
paper_year: MICRO 2000
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. Experiments show that a large portion of LLC blocks are dead, meaning that they will not see any re-reference
expect the one that brings them into the LLC. Furthermore, most re-references are seen on a small subset of blocks
that are not dead, indicating a highly concentrated hit pattern.

2. The implication of the observation is that only those blocks that will see at least one re-reference
need to be inserted into the LLC. This will not hurt performance, because those that are not inserted do not
provide any caching benefit anyway.

This paper proposes Reuse Cache, a last-level cache (LLC) design that selectively caches data only when they are
reused and thus saves storage. The design is based on the observation that most cache blocks in the LLC are useless
(i.e., will not see reference during their lifetime), and that even for useful blocks, cache hits are only concentrated 
on a small subset of them. 
The Reuse Cache leverages this observation by decoupling the tag and the data array, and enabling the tag array
to track re-reference status for non-existing blocks. This design enables the cache to have a smaller 
physical data array while achieving similar hit rates compared with a regular cache with the same associativity
and the same number of tag entries.

The theoretical foundation of cache replacement is Belady's OPT algorithm, which yields an optimal cache eviction
decision by always selecting the block in the cache whose re-reference is the furthest in the future reference
stream. The OPT algorithm, however, is unachievable, because in practice future references cannot be known in advance.
However, given a past reference history, it is possible to predict the re-reference distance of a block into the future.
For example, the LRU algorithm, which yields good result on L1 caches, assumes that cache accesses demonstrate temporal 
locality, in which an access to an address usually indicates more accesses in the near future.
As a result, if a block was just accessed, then it is likely that the block will also be accessed in the near future,
and hence the block should not be evicted by promoting it to the head (LRU side) of the LRU chain.

On the other hand, for the LLC, temporal locality is a poor indication of future re-reference, because the access
stream seen by the LLC has already been filtered by the L1 and L2 caches, which already captures most of the temporal 
locality, leaving very little for the LLC to take advantage of.
As a result, LRU does not work well on the LLC, which is observed on real workloads.
To fix this issue, Intel proposes and implements RRIP, which predicts the re-reference distance of a block based on
the number of re-references it has already seen in the past. In other words, if a block sees frequent re-references,
then it is likely that the block will also be re-referenced in the future.
Based on this assumption, the RRIP algorithm improves over LRU with two major differences.
First, when a block is first-time accessed and inserted into the cache, instead of inserting the new block 
at the head of the LRU chain as in LRU, the block is inserted into the middle of the LRU chain. 
This operation indicates that newly inserted block is only predicted as having a moderate re-reference distance.
Second, when a block is accessed by the upper level (i.e., sees a re-reference), instead of immediately moving the 
block to the head of the LRU chain as in LRU, the block is only moved towards the head by one step.
This operation implies that the more re-references a block sees, the more unlikely the block is evicted, as 
a result of being closer to the LRU head.
In practice, due to prohibitively high hardware cost of maintaining precise LRU information, the cache implementation
usually adopts narrow counters to approximate the LRU chain.

This paper confirms the underlying theory of RRIP via experiments.
In the first experiment, the cache is periodically scanned to count the number of "live" blocks, i.e., blocks 
that see at least one re-reference before being evicted.
The experiment shows that only a small fraction of blocks are actually live, while most blocks do not see any
re-reference and hence fail to provide performance benefit.
Besides, it is also shown that re-reference distance-based replacement algorithms generally perform better than LRU, 
and can keep more live blocks in the LLC.
The second experiment keeps track of the number of re-references that each block see during their lifetime
in the LLC.
Results show that around 5% of lines that are inserted into the LLC actually see re-reference. 
In addition, most hits are concentrated on a small subset of blocks that see re-reference at all.
The results from both experiments suggest that not all blocks inserted into the LLC equally contribute to the 
hit rate.
In fact, it suffices to only insert the blocks that see many re-references into the LLC, while the rest are not,
since the latter will not be re-referenced anyway and do not contribute to the benefit of caching.

To leverage the above observations, the Reuse Cache design implements a decoupled tag and data array, in which
the tag still has the same layout (number of sets and associativity as a regular cache), while the data 
array is smaller than the one in a regular cache, and can have arbitrary associativity.
Similar to other decoupled tag-data designs, each tag entry has a pointer to the data array slot that stores 
block data, and each data slot has a back pointer to the tag that stores the address.
The paper also notes that the associativity of the data array is largely arbitrary, since the associativity
only matters during replacements, which delimits the range of search for the victim block.
(Note that this may also implicitly limits the data slots a tag entry at certain set can point to, due to the 
way the data slot set index is generated).

The tag array runs NRR (Not Recently Reused) replacement algorithm.
Each tag entry has a single bit indicating whether the entry is re-referenced after being inserted 
(value being 0) or not (value being 1). 
When a new entry is inserted, the NRR bit is set to 1, and when the block is accessed again, the NRR bit is
cleared. Eviction decisions are made randomly for blocks having the NRR bit bring 1.
**If all blocks have NRR bit being 0, a case that the paper did not cover,** I think the reasonable action is to
reset all block's NRR bit to 1, and then a random tag entry is evicted from the set.
Meanwhile, data slots are evicted using either NRR or a variant using the Clock algorithm.
As mentioned earlier, the range for victim search on the data array is dependent on associativity.
The Reuse Cache enables decoupled replacement of tag array entries and data slots.
When a tag entry is evicted, the corresponding data slot is also invalidated.
However, when a data slot is replaced, the corresponding tag entry is not invalidated. Instead, the 
cache controller follows the back pointer of the data slot to find the tag entry, and then sets its coherence
state to a special value to indicate that the tag is valid, but block data is not present.

The Reuse Cache operates as follows. When an access misses the tag array, or the access hits the tag array but the
coherence state indicates that data is not present, the access is always forwarded to the main memory to fetch block 
data.
In the former case, the cache block is first time referenced, and hence only the tag array entry is inserted.
Data block fetched from the main memory is provided to the upper level, but the LLC itself will not store the
data block in its data array.
In the latter case, the LLC has already seen at least one re-reference of the block, and hence the block is deemed 
likely to be re-referenced later. In this case, the LLC controller will insert the block into the data array,
and transits the tag's coherence state to the normal state.
If an access hits both tag and data, the request is handled normally as in a regular cache.
