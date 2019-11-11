---
layout: paper-summary
title:  "nvm_malloc: Memory Allocation for NVRAM"
date:   2019-11-09 17:33:00 -0500
categories: paper
paper_title: "nvm_malloc: Memory Allocation for NVRAM"
paper_link: https://dblp.uni-trier.de/db/conf/vldb/adms2015.html
paper_keyword: malloc; NVM
paper_year: ADMS (VLDB workshop) 2015
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents nvm_malloc, a persistent memory allocator. The paper identifies that traditional memory allocators
designed for volatile memory are insufficient to ensure correct post-recovery execution for two reasons. First, without
proper metadata synchronization and post-crash recovery, memory blocks allocated to application programs might still be 
tracked as free memory after recovery, which results in data corruption as the same block can be allocated to fulfill
another memory request, causing unexpected data race. Second, memory blocks already allocated to the application may
not be persisted properly by the application, which results in memory leak. Since NVM data will not be wiped out by
simply powering down the system, the memory block is lost permanently, which can be fatal to long running applications.

The nvm_malloc design is based on two observations. First, traditional memory allocation interfaces (such as malloc/free)
are insufficient to provide the strong semantics of NVM allocation, which dictates that at any given moment in time, the
ownership of a memory block must either be the application or the allocator. This invariant is not well observed in
traditional memory allocators, because only the pointer is returned by the allocator to the application. If the crash
happens before the pointer is linked into the application data and is properly flushed back to the NVM, and after the 
allocator removes the block from its internal free list, 