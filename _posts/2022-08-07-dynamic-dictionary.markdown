---
layout: paper-summary
title:  "Dynamic Dictionary-Based Data Compression for Level-1 Caches"
date:   2022-08-07 02:54:00 -0500
categories: paper
paper_title: "Dynamic Dictionary-Based Data Compression for Level-1 Caches"
paper_link: https://link.springer.com/chapter/10.1007/11682127_9
paper_keyword: Cache Compression; L1 Compression; Frequent Value Compression; Dynamic Dictionary
paper_year: ARCS 2006
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Dynamic Frequent Value Cache (DFVC), a compressed L1 cache design using a dynamically generated
dictionary. The paper is motivated by the ineffectiveness of statically generated cache as proposed in earlier works.
The paper proposes a dynamic dictionary scheme that enables low-cost dependency tracking between compressed data
and dictionary entry in which both dictionary entries and cache blocks periodically "decay" using a global counter.

The paper begins by recognizing dictionary compression as an effective method for improving L1 access performance.
L1 caches are latency sensitive as it is directly connected to the CPU. L1 cache compression therefore must use a
low-latency decompression algorithm such that the access latency of compressed blocks is not affected.
Dictionary compression is an ideal candidate under this criterion, because decompression is simply just reading
the dictionary structure (which can be implemented as a register file) using the index.
