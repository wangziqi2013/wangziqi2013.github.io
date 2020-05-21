---
layout: paper-summary
title:  "Adaptive Cache Compression for High-Performance Processors"
date:   2020-05-20 04:20:00 -0500
categories: paper
paper_title: "Adaptive Cache Compression for High-Performance Processors"
paper_link: https://dl.acm.org/doi/10.1145/1028176.1006719
paper_keyword: Cache Compression
paper_year: ISCA 2004
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes an adaptive scheme for performing cache compression using a combination of LRU and predictors.
Cache compression serves the purpose of increasing the effective cache size, allowing more data to be cached at the 
certain level, which increases the chance that a request will hit the cache.
The paper, however, points out that cache compression is in fact a trade-off between hit latencies and hit rates.
By performing in-cache compression on write back and decompression on line fetch, more cycles are dedicated to
hardware compression and decompression, which is on the critical path. Such costs are hard to eliminate due to the 
way a cache is accessed. On the other hand, since more cache lines can be stored on a level, chances are that lines
which should have been already been evicted get hit, where in a non-compressed cache these accesses would incur misses.

This paper assumes a two-level, exclusive cache hierarchy (pressumably on a single core). The L1 cache is entirely
not compressed, since L1 latency is one of the most critical factors for instruction throughput. The 4-way set associative 
L2 runs in compression mode, which can be turned off if the system determines that no benefit is gained from compression.
The L2 cache uses LRU as replacement algorithm. The LRU stack is necessary for the algorithm to identify accesses
that gain benefit or do not gain benefit from compression. The paper also suggests that any replacement algorithm would 
work, as long as an ordered stack is maintained for a set (or more precisely, for the last few ways enabled by compression).

The L2 cache is organized as follows. Different from traditional set-associative caches where each tag is statically bound
to a data slot of 64 bytes, the L2 cache proposed by this paper does not bind tags and data slots statically. Instead,
8 tags are provisioned for each set, implying that the effective set size can be doubled in the best case. Data slots
are divided into 32 8-byte segments, which can hold 4 uncompressed cache lines, but if some or all of them are compressed,
up to 8 lines can be stored with any set in the best case. 

Tags are bound to data segments dynamically at run-time. Each cache tag contains two fields describing data: base and 
size. The base field points to one of the 32 segments as the starting segment of line data. The size field indicates the 
number of segments the line needs to take. Partial segments are always rounded up, and the compression algorithm is 
responsible to distinguish useful data from garbage from the last partially filled block. The tag also stores regular 
information, such as coherence states and address tag. One notable difference between the proposed design and a regular
cache is that the base and size field are never invalidated, unless the coherence state is "I". When a cache line is 
invalidated by an L1 request (to maintain exclusiveness) or evicted from the L2 cache, we still keep the mapping valid,
and set the state to NP, meaning valid data is not present, but the mapping is still present. When a block is acquired 
by coherence, it is set to "I", in which case segments used by the tag is unmapped.