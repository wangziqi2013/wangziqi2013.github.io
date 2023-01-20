---
layout: paper-summary
title:  "Austere Flash Caching with Deduplication and Compression"
date:   2023-01-20 02:17:00 -0500
categories: paper
paper_title: "Austere Flash Caching with Deduplication and Compression"
paper_link: https://www.usenix.org/conference/atc20/presentation/wang-qiuping
paper_keyword: SSD; Caching; Flash Caching
paper_year: USENIX ATC 2022
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Comments:**

1. Although SHA-1/SHA-256 is extremely unlikely to collide and seems to never happen in practice, the paper should
still discuss the possibility of collisions and the handling of this situation. The discussion is necessary because
future advancements in cryptography may make SHA vulnerable to hash collision attacks. 

This paper proposes AustereCache, a flash (SSD) caching design that aims at lowering runtime memory consumption while 
increasing the effective cache size with deduplication and compression. AustereCache is based on prior flash caching 
proposals that implement deduplication and compression and is motivated by their high metadata memory footprint during 
the runtime. AustereCache addresses the problem with more efficient metadata organization on both DRAM and SSD. 

AustereCache assumes a flash caching architecture where flash storage, such as Solid-State Disks (SSD), are used in 
a caching layer between the conventional hard drive and the main memory. Since SSD has lower access latency but 
is more expensive in terms of dollars per GB, the cache architecture improves overall disk I/O latency without 
sacrificing the capacity of conventional hard drives. 
