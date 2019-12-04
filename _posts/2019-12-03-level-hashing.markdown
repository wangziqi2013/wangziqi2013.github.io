---
layout: paper-summary
title:  "Write-Optimized and High-Performance Hashing Index Scheme for Persistent Memory"
date:   2019-12-03 22:57:00 -0500
categories: paper
paper_title: "Write-Optimized and High-Performance Hashing Index Scheme for Persistent Memory"
paper_link: https://dl.acm.org/citation.cfm?id=3291202
paper_keyword: NVM; Hash Table; Level Hashing
paper_year: OSDI 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes level hashing, a hash table design for byte-addressable non-volatile memory. This paper identifies three
major difficulties of implementing hash tables on non-volatile memory. The first difficulty is consistency guarantees with
regard to failures. The internal states of the hash table must remain consistent, or at least must be able to be detected
after crash by the crash recovery process. This requires programmers to insert cache line write backs and memory barriers
on certain points to guarantee correct persistent ordering, which hurts performance. The second difficulty is that DRAM-based
hash table designs may not particularly optimize for writes since DRAM write bandwidth is significantly higher than NVM 
bandwidth. On the contrary, on NVM based data structures, the number of writes must be minimized to accomodate for the lower
write bandwidth.