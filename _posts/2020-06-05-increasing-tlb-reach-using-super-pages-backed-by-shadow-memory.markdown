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
than one, due to the fact that multiple load-store unit may exist and can access the TLB in the same cycle. The third 
reason is that only one type of mapping is supported by the MTLB. Neither separate banks nor page size predictors are 
needed in MTLB. Lastly, the fine-grained mapping scheme in MTLB also enables separate permission bits for each regular
page sized block, which can be useful sometimes even for a huge page (e.g. cheap copy-on-write).

The MTLB proposal consists of three parts. The first part is the page table specification that defines the format and 
semantics of the table. The second part is the MTLB hardware that supports address translation from shadow address 
to the physical address space. The third part is Operating Systems support for MTLB. We discuss each parts in the 
following paragraphs.

The page table for shadow address space is organized as a flat, direct-mapped array. The paper argues that the storage
overhead for such an array would be reasonable, since a 32 bit pointer (recall that at the time of writing, 32 bit 
pointers is the mainstream) can map a 4KB page in the shadow address space, a mere 0.1% storage overhead. At system
startup time, the BIOS routine configures the memory controller via memory-mapped I/O by specifying the range of 
shadow address space. Typically, the shadow address space is located at high end of the physical address, and should
exclude addresses assignd for memory-mapped I/O.

The MTLB hardware is located on the memory controller, whose content is maintained by a hardware page walker.
The MTLB is organized like a set-associative cache, due to its larger capacity than an in-core TLB which is often
fully associative. The hardware page walker is simpler than the one in the MMU, thanks to the flat mapping structure of 
the shadow page table.
On servicing an incoming memory request, the memory controller first checks the target address of the request. If the 
target address is in the shadow address space, the MTLB is queried. Any invalid entry in the page table is considered
as a paged out, which is delivered back to the OS as a page fault via external exception. The paper suggests that some 
architectures do not expect page faults from an external source after in-core TLB lookup. In this case, the external
exception should indicate that the memory operation failed (e.g. parity error). On receiving such an exception, the OS
should check whether the exception target address lies within the shadow address space, and that whether it is truly a 
MTLB page fault. The MTLB hardware should set a special mark in the page table to signal the cause of the page fault.
Note that illegal access error cannot arise from a MTLB page fault, since the OS has full controler over the accessibility
of the physical and shadow address space. If an address is mapped into shadow address space, but raises a page fault, it 
must be that the OS intended to not allocate physical storage for that page until a later on-demand fill.

MTLB also maintains access and dirty bits for table entries. These entries are useful for determining eviction victims 
and for scheduling write backs. Shadow mapped pages can also be swapped out to the disk if the dirty bit is set. 
The paper points out, however, that access bits in MTLB and in the associated page table are only an approximation
of the actual access stream, due to the fact that the memory controller only sees a small subset of accesses.
Conventional algorithms such as CLOCK will not work on MTLB since the accessed bit is not set regularly for every
access from the processor. The dirty bit, on the other hand, is always accurate, since after installing or updating a 
new mapping, we always flush the cache hierarchy on the shadow address whose mapping has been changed to avoid accessing
out-of-date data. This guarantees the first write access to the shadow address region can always be seen by the memory
controller. The controller simply monitors GETX requests from the LLC, and sets the dirty bit accordingly.

The tagging logic in all levels of caches is not changed. The tags will use shadow addresses in exact the same way
as physical addresses. The cache line content, however, should be invalidated, if the shadow mapping changes. This is 
similar to how virtual address caches should be flushed on a context switch.
