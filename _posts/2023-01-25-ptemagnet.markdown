---
layout: paper-summary
title:  "PTEMagnet: fine-grained physical memory reservation for faster page walks in public clouds"
date:   2023-01-25 05:00:00 -0500
categories: paper
paper_title: "PTEMagnet: fine-grained physical memory reservation for faster page walks in public clouds"
paper_link: https://dl.acm.org/doi/10.1145/3445814.3446704
paper_keyword: Virtualization; Page Table; Buddy Allocator; PTEMagnet
paper_year: ASPLOS 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. The outer level of the nested page table suffers low spatial locality because it uses the physical addresses of the 
guest as lookup keys. As a result, even if the guest has spatial locality on its access pattern, the underlying physical
pages still will not demonstrate spatial locality. 

2. Modern OS kernel's demand paging only backs one physical page to the virtual page being accessed, causing physical
page fragmentation.



**Comments:**

1. This paper is extremely well-written with a comprehensive statement of the challenge and a good description of the 
design. But I am still surprised that there are only three pictures in the result section. 

This paper presents PTEMagnet, an Operating System kernel buddy allocator that minimizes physical address
space fragmentation and improves the performance of nested page table walks in virtualized environments.
The paper is motivated by the high degree of physical address space fragmentation when multiple memory-intensive 
processes are hosted in the same virtual machine, causing noticeable slowdowns on nested 2D page table walk. 
The paper addresses this problem using a customized kernel buddy allocator that opportunistically pre-allocates 
continuous physical pages on demand paging. As a result, page walks demonstrate better spatial locality which
improves overall system performance.

Nested page table walk has long been known to become a significant source of slowdowns in virtualized environments.
The MMU page table walker must first acquire mappings from the guest virtual address (gVA) to the guest physical address
(gPA), and then from the gPA to the host physical address (hPA). This translation requires two page tables that
perform the first and the second step of the above process, respectively.

To pinpoint the source of slowdowns during page table walks in this setting, the paper conducted a series of 
experiments, and the results indicate that most of the overheads originate from walking the outer level of the 
table, i.e., mapping from gPA to hPA. 
A more thorough investigation reveals the cause as a lack of spatial locality in the outer level of the page table,
which causes more frequent cache misses and a larger memory footprint that further reduces the effectiveness 
of page walk caches.

This phenomenon can be explained by the demand paging mechanism used in today's OS kernel design. In today's kernel, 
when the user-space application requests memory, the OS simply returns a consecutive range of virtual addresses
without backing it with physical storage. Instead, physical pages are allocated only when the virtual address
range is accessed for the first time, which triggers a page fault and traps into the OS. At this moment, the OS
allocates one single page from its buddy allocator and sets up the virtual-to-physical mapping.
Consequently, if multiple processes are co-located in the same system as they allocate memory via demand paging, 
the physical pages that each process obtains are likely to be lacking spatial locality (i.e., far away from each other 
on the physical address space) as a result of allocations being interleaved with each other.
Unfortunately, such an allocation pattern can adversely affect the efficiency of outer-level page table walks,
since the walk accesses the radix tree using the guest physical address (gPA) as a key. In this scenario, even
if the workload demonstrates spatial locality on the virtual address space, the guest physical addresses used 
for walking the outer level of the page table would still be likely to access different parts of the radix tree,
hence resulting in high cache miss ratio as well as large memory footprint.

One way to deal with the issue is to increase the spatial locality of physical pages even when multiple processes
are co-located together in the system. PTEMagnet addresses the challenge by pre-allocating 8 pages from the 
buddy allocator whenever a virtual address is accessed and requires demand paging. When adjacent virtual pages
are accessed, the pre-allocated physical pages can then be directly used to satisfy the mapping.  
The resulting memory allocation pattern demonstrates great improvements in physical address locality because it is
guaranteed that the eight consecutive virtual pages will be mapped to a contiguous range of physical pages as well.

We next describe the process as follows. In addition to the regular data structures, the kernel maintains an
extra table, the Page Reservation Table (PaRT), tracking the existing pre-allocated ranges for every eight-page 
virtual address.
When a virtual address is accessed for the first time and requires demand paging, the kernel first checks the 
PaRT to see whether the address is covered by the table. If true, then the physical page is allocated with no cost
since it is already pre-allocated. Otherwise, a new entry is inserted into the PaRT, which points to a newly allocated
eight-page block from the kernel's buddy allocator.

Pre-allocated pages can also be reclaimed by the OS when all pages in a block are freed or when the memory
pressure exceeds a certain threshold. PTEMagnet allows users to configure a threshold, which, if reached, will
trigger the kernel to reclaim pre-allocated pages. The reclamation process is simply the kernel walking the 
PaRT and freeing physical pages back to the buddy allocator until memory consumption drops below the 
threshold.
