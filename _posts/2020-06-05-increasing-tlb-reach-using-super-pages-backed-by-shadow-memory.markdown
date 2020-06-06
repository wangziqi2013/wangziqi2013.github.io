---
layout: paper-summary
title:  "Increasing TLB Reach Using Superpages Backed by Shadow Memory"
date:   2020-06-05 16:15:00 -0500
categories: paper
paper_title: "Increasing TLB Reach Using Superpages Backed by Shadow Memory"
paper_link: https://dl.acm.org/doi/10.1145/279361.279388
paper_keyword: Virtual Memory; Shadow Memory; Huge Page
paper_year: 
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes MTLB, a memory controller based TLB design aimed at extending the reach of conventional in-core TLBs.
The paper points out that conventional TLB design with standard 4KB - 8KB pages is not sufficient for achieving high
performance on modern hardware, since the reach of the TLB is only a few hundred KBs, while the first-level cache in
the system can easily exceed several MB in capacity (at the time of writing). With large working sets whose size exceeds 
the reach of the TLB, the TLB can become a bottleneck because of frequent TLB misses and page walks.

One of the existing techniques for reducing the number of entries in the TLB and therefore increasing the TLB reach
is to use huge pages, where a single TLB entry can map a significantly larger page than conventional 4KB pages. Large page
itself, however, poses a challenge to the OS's VMM, since it has a much lower tolerance for memory fragmentation, and 
much higher storage overhead if the huge page is only accessed sparsely.

MTLB solves this problem by inserting an optinal address space between the virtual and physical address space, called
real address space. The real address space is part of the physical address space, which is not backed by actual hardware
resource. The paper makes an important observation that, at the time of writing, the 32 to 40 bit physical address space
is far more than the capacity of memory modules installed, resulting in a sparsely populated physical address space.
In other words, in such a configuration, the majority of the physical address space is not used, which could be allocated
to the shadow address space. 
