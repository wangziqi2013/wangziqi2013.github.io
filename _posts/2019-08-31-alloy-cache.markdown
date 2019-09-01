---
layout: paper-summary
title:  "Fundamental Latency Trade-offs in Architecting DRAM Caches"
date:   2019-08-31 22:46:00 -0500
categories: paper
paper_title: "Fundamental Latency Trade-offs in Architecting DRAM Caches"
paper_link: https://ieeexplore.ieee.org/document/6493623
paper_keyword: L4 Cache; DRAM Cache; Alloy Cache
paper_year: MICRO 2012
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Alloy Cache, a DRAM cache design that features low hit latency and low lookup overhead. This paper 
is based the assumption that the processor is equipped with Die-Stacked DRAM, the access latency of which is lower than 
conventional DRAM (because otherwise, directly accessing the DRAM on LLC miss is always better). The paper identifies 
several issues with previously published DRAM cache designs. First, these designs usually aim for extremely high associativity.
For example, The L-H Cache stores an entire set consisting of 29 ways, including data and metadata, in a 2KB DRAM row. 
By putting the tags of a set in the same row as data, the L-H cache allows the row buffer to act as a temporary store for 
data blocks while tag comparison is being performed, known as "open page optimization". If there is a cache hit, the row 
buffer can be read again to only stream out data block without sending another command to open the row, which is a relatively
expensive operation. The high associativity design, however, inevitably puts tag access and comparison on the critical path.
In L-H cache, all 174 bytes of tags have to be read from the row before a tag comparison can be completed, resulting in 
a total 238 bytes read in order to access a block. Both accessing the tag store and performing tag comparison are conducted
on every access of the cache. The paper identifies this part of the overhead as "Tag Serialization Latency", or TSL. The 
second issue is prediction. Since row activation is a major source of latency during tag lookup, some DRAM cache designs
attempt to minimize the chance that row activation is performed by prediction whether a block will be found in the cache.
For example, in L-H cache, a MissMap is added to track the residency state of memory segments. Each segment has a tagged 
entry in the MissMap and an associated bit vector, with "1" bit representing a cached block, and "0" representing non-cached
block. The MissMap is accessed before every access of the DRAM cache, and if the query indicates a non-existent block, the 
cache will be skipped. Querying the MissMap, however, is also on the critical path of every access. In addition, the L-H 
cache paper also proposes implementing the MissMap in the LLC SRAM storage, contending for space with regular data requests.
This paper identifies this kind of extra latency as "Predictor Serialization Latency", or PSL.

One important observation made by the paper is that prior DRAM cache proposals do not truly have a lower access latency
compared with directly accessing the home location on LLC misses, due to the negative performance effect of TSL and PSL. 
These proposals, however, still demonstrate performance improvement, because they divert part of the memory traffic 
that should have been on DRAM to the on-chip Die-Stacked DRAM, leveraging the high bandwidth data link. This reduces 
contention on conventional DRAM.

Instead of implementing a highly associative cache with miss predictors, Alloy Cache puts itself on another end of the 
spectrum, featuring a direct-mapped organization and parallel cache/DRAM access. The radical design differences in fact
reflect a fundamental trade-off in cache performance: the miss rate and latency trade-off. By reducing the associativity
and removing the predictor from the critical path, we decrease hit latency of the cache at the cost of increasing the miss
rate. 

The direct-mapped Alloy Cache operates as follows. The entire cache is implemented as an array of tag and data. To
reduce the number of DRAM row activations, the tag and data are stored next to each other as a "TAD", which occupies 72 
bytes. On every cache access, the middle bits in the address are used to form the index, which is then used to compute 
the row number in the DRAM. Note that since the number of TADs per row may not be a multiple of two, we need a circuit
that can perform modular operation with a constant. The cache controller then activates the row, reads the TAD, and 
checks the tag. If there is a tag match, the data will be read. Otherwise, the current block is evicted, and DRAM is 
accessed instead. No extra LRU status need to be updated, because the eviction decision can be made instantly. Compared
with L-H cache, in which 172 bytes of tags must be fully transferred to the cache controller before determining which
data block to use, the Alloy Cache approach only reads 72 bytes of data, and in the case of cache miss, 64 of them are 
discarded.

To compensate the lower hit rate compared with other designs, Alloy cache further overlaps cache probe with DRAM access.
If the cache indicates a hit, then the DRAM lookup is aborted (results are discarded if it finishes earlier), and we use
the cached block. If the cache indicate a miss, the miss latency is reduced to the latency of cache lookup or DRAM lookup,
whichever is larger, instead of the sum of these two. This technique, however, unnecessarily increases the bandwidth to 
the DRAM if the cache indicates a hit, which should be the majority case (compared with not having an L4 DRAM cache, the 
amount of traffic stays the same). To counter this, the paper proposes using predictors to inform the cache controller 
on whether a cache access should happen in parallel with DRAM access, or they should be serialized. Two schemes of prediction
are presented in the paper. The first scheme relies on global history, which is based on the theory that cache hits and misses
usually happen in strides, i.e. if the previous accesses are hits/misses, the following access also tend to be a hit/miss. 
The global predictor can be as simple as a three-bit saturating counter. Every cache hit/miss will increment/decrement the 
counter, ignoring overflows and underflows. The cache controller uses the highest bit of the counter as the prediction output.
If it is "1", a cache hit is predicted, and the controller serialize cache access and DRAM access. If it is "0", then
both accesses are performed in parallel since we do not expect to find the block in the cache.
