---
layout: paper-summary
title:  "Frequent value compression in data caches"
date:   2022-08-07 00:43:00 -0500
categories: paper
paper_title: "Frequent value compression in data caches"
paper_link: https://dl.acm.org/doi/10.1145/360128.360154
paper_keyword: Cache Compression; L1 Compression; Frequent Value Compression
paper_year: MICRO 2000
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Frequent Value Compression in L1 data cache. The paper is motivated by frequent value locality,
a data phenomenon that a small number of frequently occurring values constitute a large portion of a program's working
set and memory traffic.
The design leverages a static dictionary, and encodes values in the cache blocks using dictionary entries. 
Since the dictionary is expected to generally capture a large portion of values in the 
cache block, these values can be represented by the index of the dictionary entry, which needs a smaller number of bits
than the uncompressed value. 
Effective cache size is hence increased by storing two compressed cache blocks into the same slot whenever possible,
achieving a maximum effective compression ratio of 2x.

