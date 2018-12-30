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
from the data structure and the number of thread holding a reference to it drops to zero. Many GC schemes were proposed 
before IBR. Reference counting is among one of the earliest GC schemes ever proposed. It works in a straightforward manner: 
When a reader thread accesses a node using a pointer, it increments a reference counter for that block atomically. Note that
since the block may have just been reclaimed before the reader thread has a chance to increment the counter (i.e. 
reader reads the pointer, another writer sneaks in, unlinkes the block, checks its reference counter which is zero,
and then reclaims the memory of the block), the reference counter should not be embedded within the block. An independent 
data structure is needed to maintain reference counters for all blocks. When a block is to be deleted, the thread
unlinked the block, and checks the reference counter. If the value is zero, then the node can be reclaimed. 
The pointer value should also be validated by re-reading the pointer field from the parent block, because otherwise 
it is possible that the block is unlinked and reclaimed before the reference counter is incremented. This issue is common 
in GC problem, if the protection of a pointer is only applied when the pointer is first used to access the block.

