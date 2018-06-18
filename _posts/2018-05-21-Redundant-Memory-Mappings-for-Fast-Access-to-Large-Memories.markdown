---
layout: paper-summary
title:  "Redundant Memory Mappings for Fast Access to Large Memories"
date:   2018-05-21 17:03:00 -0500
categories: paper
paper_title: "Redundant Memory Mappings for Fast Access to Large Memories"
paper_link: https://dl.acm.org/citation.cfm?id=2749471
paper_keyword: Paging; Virtual Memory; Segmentation; RMM;
paper_year: ISCA 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---
 
Classical virtual memory mapping relies on page tables to translate from virtual addresses to physical addresses.
If a large chunk of memory is mapped, where the address range on both the virtual address space and physical 
address space are consecutive, the translation can actually be performed on a larger granularity. This paper 
proposes redundant memory mapping, or *range mapping*, where large chunks of mapping is represented by a segment notation:
base, limit and offset. Permission bits are maintained on a segment basis where all pages in the segment must
have the same permission settings. The segment is also 4KB page aligned, and the size is always a multiple of 
the page size (4KB). We describe the details of operation below.

Range mapping cooperates with the paging system by generating TLB entries on TLB misses. Even with range mapping enabled,
the system still performs TLB lookup every time a virtual address is to be translated. This design distinguishes range mapping
from other segmentation based mapping mechanisms, including x86's native segmentation support. A range lookaside buffer is co-located 
with the last level TLB, and is activated when the last level TLB misses. Instead of conducting a page walk, the hardware TLB miss 
handler searches the range buffer using the miss address, and check whether the address is within any range table entry cached by the 
range lookaside buffer. If the address hits the range buffer, a TLB entry is generated and inserted into the TLB. The new TLB entry's 
physical address is simply the sum of the base virtual address and the offset of the range. Permission bits in the page 
table entry is derived from the permission bits in the range lookaside buffer entry. If the range lookaside buffer also misses,
the hardware page walker is activated to load the page table entry from main memory as in a normal TLB miss. In the meantime, 
a range table walker searches the in-memory range table, and loads the range into the range lookaside buffer if it exists. The 
latter is carried out in the background, and hence is not on the critical path of memory operations. If the hit range on the 
range lookaside buffer is high, then the majority of last level TLB misses can be satisfied by range mapping, rather than 
an expensive page table walk. Overall, the range lookaside buffer works as a fully associative search structure that maps a
virtual addresses to range table entries. Two comparators and one adder is required to perform the search.

The operating system is responsible for preparing a data structure called the range table in the main memory, and sets the range 
table root control register, CR-RT (like CR3), to the physical address of the root of the table. The paper suggests that the range 
table be organized as a B-Tree, with the base virtual addresses and limit as key, offset and permission bits as value. The experiments
in later sections, however, claims that using a linked list does not affect performance much. The hardware walker searches the range 
table, and loads the entry into the range lookaside buffer. The compact B-Tree representation can provide up to 128 range mappings in
a 4KB page.

The mapping specified by the range table should remain consistent with the page table. The OS should also maintain the consistency
of dirty and accessed bits between the page mapping and the range mapping. As hardware TLB coherence is lacking on x86 platform,
whenever a TLB entry is invalidated as a result of TLB shootdown, the range mapping should also be changed accordingly. 

Two optimizations can be applied to reduce energy comsumption and hardware complexity. The first optimization adds a most recented used 
range mapping buffer, which stores the most recent range mapping that was hit in the lookaside buffer. The hardware checks this MRU 
buffer first before performing a full search to the range lookaside buffer. Since ranges are usually big, and hence have strong locality,
it is likely that most lookups will hit the MRU buffer. The second optimization removes the hardware range walker from the memory
controller. A software trap is invoked when the range buffer misses, and the OS can schedule a background thread that walks the table
in software and insert an entry into the buffer. The range table in this case can have arbitrary format defined by the OS.

Range mapping works the best when both the virtual and physical addresses assigned to a process are in consecutive pages. Unfortunately, 
this is not ture in the current OS allocator implementation. Modern OSes generally takes advantage of lazy allocation. Instead of 
allocating physical pages for a virtual address range, the page table entries for the virtual address range are marked as read-only.
The first write operation to any of the pages will trigger a page fault, and the OS lazily allocates a physical page, causing 
memory fragmentation after many small allocations.
In earlier days when physical memory is usually small, this helps to reduce swapping. On modern work stations, however, swapping 
is less common. As a conclusion, in order for range mapping to work well, the OS should eagerly allocate a consecutive range of 
physical memory when virtual addresses are reserved by the application program. Having the physical pages in a consecutive range 
increases the probablity that only a few ranges can cover 90% of the application's working set. For the remaining 10%, or when 
memory fragmentation prohibits range mapping from serving its purposes, the OS could choose not to enable range mapping for 
the address space.
