---
layout: paper-summary
title:  "Black-Box Concurrent Data Structures for NUMA Architectures"
date:   2019-01-09 17:24:00 -0500
categories: paper
paper_title: "Black-Box Concurrent Data Structures for NUMA Architectures"
paper_link: https://dl.acm.org/citation.cfm?id=3037721
paper_keyword: NUMA; Concurrent Data Structure
paper_year: ASPLOS 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Node Replication (NR), which provides an efficient solution for converting a sequential data structure
to a concurrent version, which is both linearizable NUMA-aware. In NUMA architecture, all processors share the same physical
address space, while the physical memory is distributed on several NUMA nodes. A NUMA node consists of one or more cores and 
a memory module. Memory accesses from a processor have non-uniform latency, depending on address assignment.