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

Since tag lookup is an indispensable part of every cache query, regardless of the result, this paper aims at optimizing
the tag lookup overhead by storing the tags in an on-chip SRAM structure. The problem with SRAM tag store, however, is 
that for a DRAM cache of several GBs in size, the tag store will take around 10% of the data storage (assuming 6 byte tag
and metadata such as dirty bits, coherence states, etc., we compute the ratio between tag and data as 6 / 64 = 9.37%).
In the conventional set-associative scheme, in which every data slot in the DRAM cache has a corresponding tag slot
in the tag array, storing these tags will cost hundreds MBs on the chip, which is most likely not practical nowadays
and in the near future considering several factors such as cost, latency, energy, and area.