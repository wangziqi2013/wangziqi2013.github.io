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

This paper proposes AustereCache, a flash (SSD) caching design that aims at lowering runtime memory consumption while 
increasing the effective cache size with deduplication and compression. AustereCache is based on prior flash caching 
proposals that implement deduplication and compression and is motivated by their high metadata memory footprint during 
the runtime. AustereCache addresses the problem with more efficient metadata organization on both DRAM and SSD. 


