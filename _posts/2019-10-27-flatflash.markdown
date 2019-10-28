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
of virtual memory. This solution, however, has several problems. First, in virtual memory scheme, unmapped addresses 
are mapped as inaccessible pages. When such addresses are accessed by memory instructions, the system will trap into
the OS kernel, which then reads the page from the SSD, and swaps out the current page. This process involves an
OS conducted address translation, one read and one write I/O, and one TLB shootdown (this can be avoided if the shootdown
is performed lazily, i.e. we wait until the next time another core traps into the kernel by using the stale entry in
its local TLB, at the cost of more mode switches), which is rather expensive.