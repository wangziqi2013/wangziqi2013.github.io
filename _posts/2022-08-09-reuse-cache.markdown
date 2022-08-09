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


The paper begins by pointing out that while LRU is a good indication of re-use distance on 
