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
a memory module. Memory accesses from a processor have non-uniform latency, depending on the address assignment. Generally
speaking, it is faster for a processor to access memory in the same node (i.e. local memory) than to access memory from 
a different node (i.e. remote memory). If not designed properly, a NUMA-oblivious data structure may suffer from the 
worst case scenario where most memory requests have to be served by a remote memory, which easily tanks performance.

