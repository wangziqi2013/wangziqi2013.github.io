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
allocator removes the block from its internal free list, the block is permanently lost, since neither the allocator
nor the application owns the memory. This problem, in its essence, is caused by non-atomic ownership transfer: During 
the ownership transfer, there is a short time window in which the block is not owned by any party in the system, whose 
only reference is stored on the volatile stack. On a power loss, the stack content will not be preserved, resulting in 
memory leaks. The second observation is that recovery does not require the allocator to restore everything to the exact
consistent state at the byte level, as long as the logical view of memory is preserved. This important observation leads
to the practice in which two copies of metadata being maintained for the allocator. The persistent copy, which is the
NVM image of the allocator state, is only updated and read sparsely when absolutely necessary. This way we can organize 
the NVM metadata in a way that is most efficient for logging and recovery. The DRAM copy of the metadata, on the other 
hand, is queried every time a request is received. We organize DRAM metadata such that lookup and update performance is 
optimized, while persistence and durability is not a concern. These two copies of metadata is only synchronized regularly 
at certain points during the operation, such as when a new block is allocated to the application. On recovery, we rebuild
the DRAM copy of metadata by scanning entire or only part of the NVM storage. This can be done by a background thread
or lazily.