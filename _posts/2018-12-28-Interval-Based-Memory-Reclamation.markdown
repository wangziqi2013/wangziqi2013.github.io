---
layout: paper-summary
title:  "Interval Based Memory Reclamation"
date:   2018-12-28 22:07:00 -0500
categories: paper
paper_title: "Interval Based Memory Reclamation"
paper_link: https://dl.acm.org/citation.cfm?doid=3178487.3178488
paper_keyword: TLB Shootdown
paper_year: ASPLOS 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Interval-Based Memory Reclamation (IBR) as a way of performing Garbage Collection (GC) in 
lock-free data structures. In a lock-free data structure, since readers usually do not synchronize with writers, 
if a writer thread removes a block accessible via a pointer, it is possible that one or more readers still
have a reference to that block, and hence the actual reclamation of the block should be delayed. To ensure safe access
of memory blocks for readers, the GC scheme should guarantee that a block is only removed after it has been unlinked
from the data structure and the number of thread holding a reference to it drops to zero. 
