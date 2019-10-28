---
layout: paper-summary
title:  "FlatFlash: Exploiting the Byte-Addressibility of SSDs within a Unified Memory-Storage Hierarchy"
date:   2019-10-27 22:12:00 -0500
categories: paper
paper_title: "FlatFlash: Exploiting the Byte-Addressibility of SSDs within a Unified Memory-Storage Hierarchy"
paper_link: https://dl.acm.org/citation.cfm?doid=3297858.3304061
paper_keyword: SSD; Virtual Memory; FlatFlash
paper_year: ASPLOS 2019
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes FlatFlash, an architecture that allows SSDs to be connected to the memory bus and used as 
byte-addressable memory devices. While the size of big data workloads keep scaling, the capacity of DRAM based memory 
in a system cannot grow as fast as the size of the workload. Current solutions for solving the memory scarcity problem
is to use SSDs as backup storage accessed in block granularity, leveraging the address mapping and protection capability 
of virtual memory. This solution, however, has several problems. 