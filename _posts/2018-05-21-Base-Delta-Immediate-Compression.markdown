---
layout: paper-summary
title:  "Base-Delta-Immediate Compression: Practical Data Compression for On-Chip Caches"
date:   2018-05-21 22:47:00 -0500
categories: paper
paper_title: "Base-Delta-Immediate Compression: Practical Data Compression for On-Chip Caches"
paper_link: https://dl.acm.org/citation.cfm?id=2370870
paper_keyword: Cache Compression; Delta Encoding
paper_year: PACT 2012
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes an simple and yet effective cache compression architecture. Compressing cache lines 
for L2 cache and LLC increases effective cache associativity, reducing conflict misses. To store the compressed 
cache line, the paper proposes doubling the number of tags in each set. This design allows at most two cache lines to
be stored compactly inside a 64 byte line while maintaining the number of data storage unchanged. Since the majority of 
the resources of the cache system are devoted to data storage, only doubling the size of the tag array has a minimum
effect. Power consumption, however, can become worse, as the comparator used for comparing tags must also be doubled.

To reduce the negative effect of increased load and store latency, compression is only applied to shared L2 and L3 caches,
but not L1. The priority should be put on decompression, as it is usually on the critical path of load instructions. 
In contrast, decompression can usually be performed on the background after the critical word is supplied to the processor.

