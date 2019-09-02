---
layout: paper-summary
title:  "Tag Tables"
date:   2019-09-01 20:03:00 -0500
categories: paper
paper_title: "Tag Tables"
paper_link: https://ieeexplore.ieee.org/document/7056059
paper_keyword: L4 Cache; DRAM Cache; Tag Table; Page Table
paper_year: MICRO 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes tag table, a tag encoding technique for tag store of large DRAM L4 cache. Conventional DRAM caches,
such as L-H cache and Alloy Cache, store cache tags of blocks within the DRAM, usually at the same row as block data to
achieve lower latency, leveraging the row buffer to avoid activating two different rows for one access. This approach,
however, still requires one row activation operation, which is relatively quite expensive compared with SRAM read and 
DRAM column read, which is on the critical path of cache query.

