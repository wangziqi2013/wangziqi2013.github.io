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

