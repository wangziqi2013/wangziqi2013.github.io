---
layout: paper-summary
title:  "Efficient Footprint Caching for Tagless DRAM Caches"
date:   2018-06-16 00:00:00 -0500
categories: paper
paper_title: "Efficient Footprint Caching for Tagless DRAM Caches"
paper_link: https://ieeexplore.ieee.org/document/7446068/
paper_keyword: cTLB; DRAM cache; tagless; footprint caching; over-fetching
paper_year: HPCA 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper extends the idea of Tagless DRAM Cache, and aims at solving the over-fetching
problem when main memory is cached in page granularity. The over-fetching problem states that
if the locality of memory accesses inside a page is low, the bandwidth requirement and latency for 
bringing the entire page into L4 cache cannot be justified by the extra benefit it introduces. Footprint 
caching, on the other hand, transfers data at 64 byte cache line guanularity and lazily fetches only cache 
lines that are accessed. The frequently accessed cache lines in a page are recorded as the metadata
of the page in the page table when the cache block is evicted. The next time the page is fetched from the main 
memory due to a cache miss, only the frequently accessed lines will be transfered. Footprint caching maintains 
a high hit rate while reduces the bandwidth requirement of ordinary page based caching. In the following sections
we will present a design in which footprint caching is integrated into tagless DRAM cache in order to 
solve the over-fetching problem.

Tagless DRAM cache emerges as on-die DRAM now becomes available on commercial hardware. On-die DRAM
typically has lower access latency compared with the main memory DRAM, but has less capacity. To make the 
best use of it without overburdening the OS with complicated memory allocation and scheduling problem, hardware 
designers have proposed to dedicate the extra hundreds MBs or even few GBs of storage to serving as an L4 cache. 
The challenge, however, is that if DRAM caches are to be organized just like the SRAM cache, the storage 
for the tag array would be tens of MBs in size, which is not feasible to be implemented on-chip. One of the solutions
that is relevant to our topic is the *tagless DRAM* design, where the L4 cache does not use tags to identify blocks.
Instead, the TLB is extended with a "cache address" field, in which the location of the block in the DRAM cache 
can be located using this pointer. Caching is always performed on page granularity. The system maintains an 
invariant that as long as a TLB entry is valid, the corresponding page must be cached in L4. 