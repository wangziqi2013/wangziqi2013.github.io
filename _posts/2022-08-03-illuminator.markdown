---
layout: paper-summary
title:  "Making Huge Pages Actually Useful"
date:   2022-08-03 23:36:00 -0500
categories: paper
paper_title: "Making Huge Pages Actually Useful"
paper_link: https://dl.acm.org/doi/abs/10.1145/3173162.3173203
paper_keyword: TLB; Huge Page; Virtual Memory; Illuminator; THP
paper_year: ASPLOS 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Illuminator, a virtual memory technique that reduces the overhead of memory compaction for 
Transparent Huge Pages (THP).
Illuminator is motivated by the inefficient implementation of memory compaction in current Linux kernel THP caused by 
unmovable kernel pages. 
The paper proposes that memory compaction should be done with unmovable pages taken into consideration such that the
kernel does not attempt to allocate huge 2MB pages with unmovable 4KB pages allocated in it.
