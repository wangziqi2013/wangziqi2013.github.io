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

**Highlights:**

1. Existing memory compaction mechanism suffers from fragmented address space, which affects the success rate of 
allocating 2MB chunks, and unmovable pages that contain kernel data structures, which incurs wasted work and 
increases the latency of synchronous compaction.

**Comments:**

1. Are all 2MB chunks in the hybrid pool checked on every compaction? If compaction is expensive, then this seems
to be of little overhead, though. 

2. How does Illuminator know the number of kernel and non-kernel pages on a chunk? Does it add new counters to the 
per-chunk structure?

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
Initially, all 2MB chunks in the system are added to the movable pool. When the kernel requests a page from one of the 
2MB chunks, if the chunk is still in the movable pool, then it is moved to the unmovable pool.
Unmovable allocations are satisfied by chunks in the unmovable pool, unless the pool is full, in which case a 
chunk from the movable pool is used.
Similarly, non-kernel allocations are satisfied from the movable pool, unless the pool is full, in which case a 
chunk from the unmovable pool is used, and that chunk is moved into the movable pool.
In addition, page free does not change the pool a chunk belongs to, because that would require scanning all
pages in the chunk, which is a time consuming task, and it lies on the critical path of the buddy allocator.

The paper points out three issues with the above memory compaction process.
First, the process does not minimize fragmentation, causing many pages to be unmovable, since the two pools both 
lack information on how unmovable pages are distributed on each chunk.
As a result, 2MB allocation will be less likely to succeed compared with the case where fragmentation is minimized.
Second, fragmentation will cause the latency of synchronous compaction (which happens during page fault) to increase.
This is because a chunk containing one or more unmovable pages will fail to be compacted, which wastes all compaction 
efforts that have been spent on the page.
Note that this increased overhead can, in fact, be prevented by the kernel by checking the status of all
baseline pages in the 2MB chunk before the compaction begins. The paper claims that the kernel design appears to
choose to allow the longer latency as a trade-off for less future fragmentation.
The last issue is that Linux kernel adopts RCU to allow concurrent access to shared memory objects. RCU will increase
the lifespan of pages containing objects that are accessed by RCU, since it delays the actual deallocation of objects 
only till after the grace period, which prevents pages containing those objects from being freed to the page allocator.

To address all these issues, the paper proposes Illuminator, which improves over the current implementation by having
three pools, instead of two, to better distinguish between 2MB chunks. 
In addition to the movable and movable pools, which consist of chunks that consist of all unmovable and all movable 
pages, Illuminator adds a new hybrid pool, which consists of chunks that contain both movable and unmovable pages.
Kernel page allocation will always be fulfilled from the unmovable pool first, and if it fails, then from the 
hybrid pool. The allocation will only be satisfied from a unmovable pool chunk if the first two both fail, in
which case the chunk is moved to the hybrid pool.
Illuminator therefore minimizes fragmentation by always allocating from the hybrid pool before turning to the 
unmovable pool.

To reduce the latency of synchronous page compaction, Illuminator only selects a chunk as the candidate for page
compaction if the chunk is in the movable pool, which is guaranteed to only contain movable pages. 
Pages in the hybrid and unmovable pool contain, meanwhile, may contain movable pages, but they are also likely
to contain unmovable pages, making them bad candidates for compaction.

As movable and unmovable pages are freed, the hybrid pool chunks may become qualified for the unmovable or movable pool.
This check is performed during compaction, where the compaction process also tests the number of movable and 
unmovable pages for every chunk in the hybrid pool.
If a chunk only contains kernel pages, then it will be moved to the unmovable pool. Otherwise, if a chunk only contains
non-kernel pages, then the chunk will be moved to the movable pool.

To address the delayed page deallocation problem brought by RCU, the paper proposes replacing the default slab 
allocator with a new page allocator, Prudence, which integrates with RCU for rapid object recycling.
Prudence reduces the lifetime of pages containing RCU objects, and as a result, decreases the number of pages
requested from the OS page allocator.
