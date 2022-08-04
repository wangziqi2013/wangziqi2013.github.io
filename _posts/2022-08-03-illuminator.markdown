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

The paper points out that there are two ways 2MB huge pages (which is what the paper mainly focuses on) can be 
utilized by the software stack. The first is libhugetlbfs, which requires explicit software collaboration, and 
runtime information on memory access patterns. 
The second is Transparent Huge Page (THP), which is a kernel functionality that attempts to map existing baseline pages 
(i.e., 4KB standard pages) using 2MB huge pages without user intervention. 
In THP, aligned 2MB physical memory chunks need to be allocated to back 2MB virtual pages. This task, however, is not
always possible, given that the physical memory can often be fragmented, in which case there is sufficient amount of
memory, but no consecutive 2MB physical chunks exist.

To deal with fragmentation, the kernel uses a kernel thread, khugepaged, to periodically compact pages by copying 
valid baseline pages from 2MB chunks to be selected for allocation into other 2MB chunks that still have free 
baseline page slots.
Since the virtual memory system hides the physical address for user space programs, the page compaction process is
transparent to application programs.
This process, however, cannot move pages that contain kernel data structures, because kernel refers to its own data 
structure using a special virtual address range that direct-maps the entire physical address space.
The virtual-to-physical mapping in this direct-mapped region is hardwired, and cannot be changed even for page 
compaction. 
As a result, khugepaged cannot allocate 2MB chunk, if the chunk contains an unmovable page.

To increase the chance that 2MB chunks can be successfully allocated, current system uses some fragmentation reduction
mechanism described as follows. 
All physical 2MB frames are divided into two pools, one "unmovable pool" that contains 2MB chunks that are likely to
contain at least one unmovable baseline pages, and a "movable pool" that contains 2MB chunks that are unlikely 
to contain any unmovable page.

