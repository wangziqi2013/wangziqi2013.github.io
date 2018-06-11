---
layout: paper-summary
title:  "Bit-Plane Compression: Transforming Data for Better Compression in Many-Core Architectures"
date:   2018-06-010 16:54:00 -0500
categories: paper
paper_title: "Bit-Plane Compression: Transforming Data for Better Compression in Many-Core Architectures"
paper_link: https://ieeexplore.ieee.org/document/7551404/
paper_keyword: BPC; Compression; Bit Plane
paper_year: ISCA 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Compressing for main-memory can be beneficial as it saves both capacity and bus traffic. This paper mainly focuses 
on the latter, without presenting in a detailed manner how compressed blocks are stored and indexed in the DRAM array.
There exists several design trade-offs for memory compression architectures. For examples, designing for cache only
compression significantly differs from designing for main memory compression, because the former could employ
techniques such as re-compression and fast indexing structures with relatively low overheads, while the latter 
usually could not afford so. The compression algorithm is also of great importance to the overall system design.
Classical fixed-length encoding may be favored as they can approximate the entropic limit. The computational 
complexity on hardware, on the other hand, can be prohibitive. Variable lengthed encoding with a dictionary
could work for cache only compression, but the overhead of the dictionary when applied to the main memory can 
overshadow its benefit.

This paper proposes Bit-Plane Compression (BPC), which is specifically tuned for GPGPU. GPGPU systems benefit from
compression for two reasons. First, the 
