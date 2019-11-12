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

We first describe the NVM image of nvm_alloc metadata. The allocator divides the address space into chunks, which are fixed 
sized, 4MB blocks requested from the OS. Each chunk has a chunk header if it is not allocated, or if it is the first chunk
of an allocated huge block (a block may span several chunks). Huge allocations greater than 2MB are fulfilled directly
by one or more continuous chunks. Some chunks are maintained as arenas to fulfill allocation requests of moderate sizes. 
Arenas are self-contained, in a sense that all metadata related to allocation is contained in the arena, and that
multiple arenas can handle allocation in parallel independently. Threads are mapped to different arenas to minimize contention.
Within an arena chunk, we further break down memory into 4KB blocks. Allocation sizes and metadata headers are both rounded 
into cache line granularity (64 Bytes), and aligned to cache line boundaries to avoid unexpectedly persisting unrelated 
data due to false sharing. Within an arena, allocation requests are classified into two types. For requests larger than 
2KB but smaller than 2MB, they are directly fulfilled from consecutive free blocks within the arena, if there is any (if 
not then threads check other areas, or allocate a new chunk). The first block of the allocation is initialized with a 
header which describes the type and size of the allocation. For requests less than 2KB, they are fulfilled by a single 
block which we describe as follows. The allocator further classifies the requested size into different size classes. For 
each size class, there is a linked list of blocks that fulfill allocation of this class. One block can only be used for 
one size class. Within the block, the first 64 bytes are dedicated to the block header, which stores the block
type, the ID of the arena, and an 8 byte bit map (63 entries at most) for describing the availbility of slots in the unit
of the current class size. When a small allocation is made from a block, the corresponding bit is set to indicate that
the block is no longer owned by the allocator.

Several invariants are maintained by the allocator to ensure correct recovery. First, all allocated blocks are aligned to
64 byte cache line boundary to avoid false sharing, as we have discussed above. Second, for every allocation, the metadata
header describing this allocation (and potentially other allocations, in the case of small requests) is always located in
the first cache line sized area as the pointer returned. This implies that the metadata describing the allocation
can always be located by aligning down (i.e. towards lower address) data pointer to the nearest block boundary (i.e. 4KB). 
The third invariant is that at aby given moment in time, a block is either owned by the allocator, or owned by the application.
The ownership transfer is performed using an atomic operation at hardware level, assuming that single word store and single 
cache line write back are atomic with regard to failures.