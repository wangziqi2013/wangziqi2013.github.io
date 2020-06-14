---
layout: paper-summary
title:  "Skewed Compressed Caches"
date:   2020-06-13 22:27:00 -0500
categories: paper
paper_title: "Skewed Compressed Caches"
paper_link: https://dl.acm.org/doi/10.1109/MICRO.2014.41
paper_keyword: Compression; Cache Tags; Skewed Cache
paper_year: MICRO 2014
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes skewed compressed cache, a compressed cache design that features skewed set and way selection.
The paper identifies three major challenges of designing a compressed cache architecture. The first challenge is to
store compressed blocks compacted in the fixed size physical slot. Since compressed block sizes could vary significantly
based on the data pattern, sub-optimal placement of compressed data will result in loss of effective cache size and 
more frequent compaction operation on the data slot. The second challenge is to minimize the number of tags while making
the best use of the physical storage. In the conventional scheme where each tag could only map one logical block, 
designers often have to over-provision tags to enable storing more logical blocks in the cache, which also increases
area and power consumption. The third challenge is to correctly locate the compressed block in the physical storage,
since on compressed architectures, blocks are not necessarily stored on a pre-defined size boundary, which must be
explicitly coded into the tag as well. In addition, the associativity between tags and physical slots are often more
flexible to enable one tag to map any or a subset of segments (assuming segmented cache design) in the current set.

In order to solve these challenges, the paper noted that two types of locality exist in the majority of the workloads.
Spatial locality exists such that adjacent address blocks are often brought into the LLC by near-by instructions, which
are also cached in the LLC at the same time. Meanwhile, these adjacent blocks are also tend to be compressed into similar
sizes, due to the usage of arrays and/or data structures containing small integers, etc.
These two observations, combined together, suggest that blocks 