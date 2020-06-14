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
These two observations, combined together, suggest that blocks that are adjacent to each other could be cached with little
tag and external fragmentation overhead, since one tag plus an implicit offset is sufficient to generate the address of 
a block, similar to address computation in sector caches. In addition, adjacent blocks can be stored compactly without 
worrying too much about physical storage management, since they can just be classifyed into one uniform size, and be 
naively stored as fixed size blocks.

This paper also borrows the skewed cache design in uncompressed caches. The original idea skewed cache is based on the 
fact that real-world workloads often do not distribute accesses evenly too all sets, underutilizing some sets while 
incurring excessive conflict misses on some other sets. To reduce conflict misses, the skew cache design proposes that
the cache be partitioned into equally sized ways, and that different hash functions be used on different ways to locate
the tag. By using different hash functions, the "conflict with" relation is no longer transitive: In the regular cache
design, if address A, B conflict on set X, and B, C also conflict on set X, then A, C will always conflict on the 
same set. This is no longer true in a skewed cache, since each way now has its own conflict relation. Two addresses
conflicting on way W1 does not necessarily suggest that they also conflict on way W2, thus guaranteeing addresses
that will be conflicts with each other in a regular set-associative cache being unlikely to conflict, resulting in
higher cache hit ratio. 
