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

In the following discussion, we use the word "chunk" to refer to the 4MB block used to support huge allocation and arenas.
We use "block" to refer to the 4KB memory block which is the granularity of alignment for headers, and the granularity
for large allocations. We use "region" to refer to a consecutive range of blocks, which can be either free or already
allocated.

Several invariants are maintained by the allocator to ensure correct recovery. First, all allocated blocks are aligned to
64 byte cache line boundary to avoid false sharing, as we have discussed above. Second, for every allocation, the metadata
header describing this allocation (and potentially other allocations, in the case of small requests) is always located in
the first cache line sized area as the pointer returned. This implies that the metadata describing the allocation
can always be located by aligning down (i.e. towards lower address) data pointer to the nearest block boundary (i.e. 4KB). 
The third invariant is that at aby given moment in time, a block is either owned by the allocator, or owned by the application.
The ownership transfer is performed using an atomic operation at hardware level, assuming that single word store and single 
cache line write back are atomic with regard to failures. The last invariant is that all allocated region and free region
have a header, which stores the arena ID of the region, the type of the region (free, huge allocation, large allocation,
or block for a certain size class), the allocation status (discussed later), and the size of the allocation. There are 
also type-specific information such as allocation bit map, etc.. As mentioned earlier, the header is of single cache line 
size, and is aligned to cache line boundaries. This allows headers to be identified during recovery by simply scanning 
the NVM address space, and jumping over the region body to the next region.

We next describe the in-memory data structure that nvm_malloc uses to support fast query. First, each chunk has a search
tree which tracks free regions sorted by block address. Initially, the entire chunk is only one large region consisting of
all blocks in the chunk except the first one (which is used for metadata and alighment). As blocks and regions are allocated, 
existing regions in the search tree are selected in a best-fit basis, broken down to smaller regions, and re-inserted into 
the tree. As mentioned earlier, each region in the tree has a header which describes the current state of the region. 
When a large region is broken down into smaller ones, a new header is written to the newly created region (which is at 
the middle of the existing region), flushed back to the NVM, only after which can we modify the header of the existing 
region, and flush back the modified header. This order of operation guarantees that even the system crashes at the middle 
of the region break-down, as long as the dirty value of the exiting header is not written back to the NVM, the break
will not be committed. During recovery, the newly allocated region is merged back to the original region as if it has
never happened, since the larger region's size is still the original size. We will not be able to recognize the newly
written region header at the middle of the original region during the scan. 

Each arena in nvm_malloc has a list of buckets, which holds metadata for different size classes. Each bucket in the arena
represents a certain size class, which has a linked list of blocks dedicated to that size class. nvm_malloc only stores
the headers of these blocks in the DRAM as a link list, from which free slots can be acquired by reading in the allocation
bit map of each block and finding the index of a "0" bit. Full blocks are removed from this list, since they can no
longer be used. When a pointer is freed, we first round down the pointer value to the nearest block boundary,
and check if it is a slotted block. If true, then the block header is re-added into the linked list. 

nvm_malloc features a set of interfaces that are different from traditional malloc/free, the major reason of which is to
enforce atomicity of ownership transfer. Memory allocation is processed in two steps. In the first step, the metadata
within nvm_malloc is searched and a new block is allocated. This process happens entirely in DRAM, and only the DRAM 
metadata is modified to reflect the change. Concurrent allocation is serialized by locks on the arena and free list 
(they are not serialized, however, when a small and a large allocation are invoked by different threads at the 
concurrently, as long as the free list has at least one block). This step is called "reserve" in the paper, which
uses a malloc-like interface (i.e. the pointer is returned as a value). In the next step, the newly allocated block is 
"activated" by writing log entries to the header of the allocated memory. Threads call a function "nvm_activate" with
both the pointer just returned from the allocator, and addresses that will be updated with the allocated pointer ("target 
words"). Due to space limit of the header (64 bytes), at most two target words can be passed to the allocator, and for 
slotted page allocation, at most two activations can be logged in the header (for the other two types of allocations,
we can only have at most one activation record). The allocator then performs ownership transfer atomically as follows.
First, it writes the address of the target words into the header, and flush the header. Next, the allocator changes the 
status word in the header from "Free" to "Pending" to reflect the allocation. For slotted page allocations, the 
index should also be logged, and the bitmap should also be updated (before updating the status word). In the 
third step, the header is flushed back to the NVM again to activate the allocated address. After the flush, the target 
words are updated with the address of the allocated block, and then flushed back to the NVM. In the last step, the status 
word is changed from "Pending" to "Allocated" and then flushed, which implicitly invalidates the log entries in the header. 

The second flush operation is the linearization point of the ownership transfer: If system crashes before this happens, 
the block is still in Free state on the NVM, and therefore not allocated, and the application will not be able to access 
them, since the target word values have not been updated. If the system crashes after the second flush, the status word
is "Pending", which will cause the recovery process to reapply the last two steps described above, which updates the 
target words with the allocated value. The last flush is simply log pruning to avoid excessive and unnecessary log replay.
Deallocation works similarly: Instead of setting the target words to the allocated value, we simply set them to NULL 
pointer, and change the status word to "Free Pending". 

On recovery, the recovery process starts a background thread to scan the NVM address space. It begins with the lowest known 
header address (which is mapped to a well-known location in the virtual address space), and keeps scanning by jumping to 
the next header indicated by the size field in the current header. If the header status word indicates that there are 
activation operations pending, the recovery process simply writes the region address to target words recorded in the 
header. In the meantime