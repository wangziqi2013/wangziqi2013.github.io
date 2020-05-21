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
not compressed, since L1 latency is one of the most critical factor for instruction throughput, while L2 runs in 
compression mode, which can be turned off if the system determines that no benefit is gained from compression.