---
layout: paper-summary
title:  "EveryWalk’s a Hit: Making PageWalks Single-Access Cache Hits"
date:   2022-07-24 03:51:00 -0500
categories: paper
paper_title: "EveryWalk’s a Hit: Making PageWalks Single-Access Cache Hits"
paper_link: https://dl.acm.org/doi/abs/10.1145/3503222.3507718
paper_keyword: TLB; Virtual Memory; Page Walk
paper_year: ASPLOS 2022
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes a novel page table and MMU co-design that reduces the overhead of address translation misses
on large working sets.
The paper is motivated by the fact that today's application generally has working sets at GB or even TB scale, 
but the capability of hardware to cache translation fails to scale proportionally. 
As a result, address translation misses becomes more frequent, and becomes more and more of a performance bottleneck.
The situation is only worsened by the introduction of virtualization, which requires a 2D page table and nested 
address translation, and the five-level page table that comes with the bigger virtual address space.
This paper seeks to improve the performance on address translation from two aspects: (1) Reducing the number of 
steps in page table walk by using huge pages for page tables, and (2) Reducing the latency of each step of 
page table walk with better caching policies.

The paper observes that existing radix tree-based page table designs always map radix nodes in 4KB granularity,
which is also the minimum unit supported by address translation. While larger granularity page mapping for data
pages are available as huge pages in the form 2MB and 1GB pages, these huge pages are not available 
for page tables.

The paper assumes a x86-like system with four levels of page tables, but does not exclude other possible designs
such as five-level page tables. 
Address translations are performed by the two-level TLB structure, and when the TLB misses, a page walk is conducted
to retrieve the address translation entry from the page table in the main memory.

