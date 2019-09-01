---
layout: paper-summary
title:  "Fundamental Latency Trade-offs in Architecting DRAM Caches"
date:   2019-08-31 22:46:00 -0500
categories: paper
paper_title: "Fundamental Latency Trade-offs in Architecting DRAM Caches"
paper_link: https://ieeexplore.ieee.org/document/6493623
paper_keyword: L4 Cache; DRAM Cache; Alloy Cache
paper_year: MICRO 2012
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Alloy Cache, a DRAM cache design that features low hit latency and low lookup overhead. This paper 
is based the assumption that the processor is equipped with Die-Stacked DRAM, the access latency of which is lower than 
conventional DRAM (because otherwise, directly accessing the DRAM on LLC miss is always better). The paper identifies 
several issues with previously published DRAM cache designs. First, these designs usually aim for extremely high associativity.
For example, The L-H Cache stores an entire set consisting of 29 ways, including data and metadata, in a 2KB DRAM row. 
By putting the tags of a set in the same row as data, the L-H cache allows the row buffer to act as a temporary store for 
data blocks while tag comparison is being performed, known as "open page optimization". If there is a cache hit, the row 
buffer can be read again to only stream out data block without sending another command to open the row, which is a relatively
expensive operation. The high associativity design, however, inevitably puts tag access and comparison on the critical path.
In L-H cache, all 174 bytes of tags have to be read from the row before a tag comparison can be completed, resulting in 
a total 238 bytes read in order to access a block. Both accessing the tag store and performing tag comparison are conducted
on every access of the cache. The paper identifies this part of the overhead as "Tag Serialization Latency", or TSL. The 
second 