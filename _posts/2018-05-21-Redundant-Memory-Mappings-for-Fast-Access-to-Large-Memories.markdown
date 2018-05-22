---
layout: paper-summary
title:  "Redundant Memory Mappings for Fast Access to Large Memories"
date:   2018-05-21 17:03:00 -0500
categories: paper
paper_title: "Redundant Memory Mappings for Fast Access to Large Memories"
paper_link: https://dl.acm.org/citation.cfm?id=2749471
paper_keyword: Paging; Virtual Memory; Segmentation
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
an expensive page table walk. 

The operating system is responsible for preparing a data structure called the range table in the main memory, and sets the range 
table root control register, CR-RT (like CR3), to the physical address of the root of the table. The paper suggests that the range 
table be organized as a B-Tree, with the base virtual addresses and limit as key, offset and permission bits as value. The experiments
in later sections, however, claims that using a linked list does not affect performance much. The hardware walker searches the range 
table, and loads the entry into the range lookaside buffer. The compact B-Tree representation can provide up to 128 range mappings in
a 4KB page.