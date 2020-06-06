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
is far larger than the capacity of memory modules installed, resulting in a sparsely populated physical address space.
In such a configuration, the majority of the physical address space is not used, which could be allocated
to the shadow address space. Memory requests to the shadow address space are translated using a mapping table and a
memory controller TLB (MTLB) to physical addresses. 
There are two obvious advantages of performing two-level address translation with the shadow address space.
First, since the shadow address space is large, memory fragmentation is no longer an issue. The OS could just maintain 
a larger address pool, and select the most suited address block from the shadow address space as the target address for 
virtual memory mapping.
Second, the MTLB can still map shadow addresses in 4KB granularity, which enables more flexible memory management
while keeping address translation overhead low on the performance-critical in-core TLB.

The paper also finds adding a seperate TLB to the memory controller appealing for several reasons. First, this TLB is 
only accessed when a memory request is issued from the LLC, and the target address is within the shadow address space.
Since most memory requests just hit the cache hierarchy without making to the memory controller, the load on the MTLB
is usually light, enabling a design with simpler hardware and a larger array. Second, the MTLB only needs one read and 
write port, since at most one memory request can be handled at a time for most controllers. In-core TLBs may need more 
than one, due to the fact that multiple load-store unit may exist and can access the TLB in the same cycle. The last 
reason is that only one type of mapping is supported by the MTLB. Neither separate banks nor page size predictors are 
needed in MTLB.


