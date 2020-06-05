---
layout: paper-summary
title:  "Perforated Page: Supporting Fragmented Memory Allocation for Large Pages"
date:   2020-06-05 11:24:00 -0500
categories: paper
paper_title: "Perforated Page: Supporting Fragmented Memory Allocation for Large Pages"
paper_link: https://www.iscaconf.org/isca2020/program/
paper_keyword: Virtual Memory; Perforated Page
paper_year: 
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes perforated page, a virtual memory extension for supporting huge pages with little memory fragmentation
overhead. Existing huge page support on commercial processors rely on the OS's ability to find large physical address 
chunks which can then be mapped to an aligned 2MB virtual address range. Huge pages reduce the number of TLB entries
for mapping a consecutive range of memory than using regular 4KB pages. This design, however, has to overcome several 
difficulties such as memory fragmentation and data movement overhead. The paper identifies three major challenges 
while using huge pages. The first challenge is memory bloating, which happens when a huge page is only sparsely accessed.
Since huge pages must be assigned physical storage as a whole, most memory storage is wasted. With regular 4KB page,
this will not be an issue, since each 4KB page can be mapped individually. This is especially problematic if the OS
has Transparent Huge Page (THP) enabled, in which the OS's VMM detects allocation pattern that can fit into a huge page,
and automatically use huge pages to satisfy the allocation. The OS has no idea about the access pattern of these allocated
huge pages, resulting in possible mismatch between page size and access density.
The second challenge is deduplication, which is implemented by some application level software and/or the OS kernel.
The deduplication process tries to find identical pages mapped by different processes, and then remap them to the same
physical frame. With 2MB huge page, the chance that an iddentical page be found is most likely small, since a single byte
within the 2MB range will render deduplication impossible. As a result, the OS needs to actively decompose huge pages 
previously allocated into standard 4KB pages. This not only creates extra memory management overhead, but also increases
TLB pressure, since more entries are needed to map the same physical memory. 
The last challenge is posed by the fact that the OS will also actively compact physical pages to reduce fragmentation,
and then promote large chunks of memory into huge pages. The background compact and promoting process incurrs extra 
memory traffic, since physical pages are copied around for defragmentation. 

Perforated page design solves the above issues by allowing huge pages to be mapped with an unlimited number of 4KB "holes" 
in the virtual address space, making the 2MB virtual address range partially non-consecutive. These holes in the 2MB page
serve three differeit purposes. First, virtual address holes do not need to be backed by any physical pages. If a hole
is known to be never accessed by the application, the physical page backing the hole can be released, which increases
memory utilization. Second, even if holes are backed by physical memory, they enable the OS's VMM to somehow exert finer
grained management over the mapped page. In the deduplication examples above, a deduplicated "hole" page can be individually 
allocated, if it is to be mapped by multiple different processes. The last purpose is that 2MB pages can be mapped with
a physical address layout which contains valid 4KB pages in the 2MB physical range. As long as virtual addresses that
correspond to these valid pages are remapped as "holes", even a highly fragmented physical address layout could support
huge page mapping, eliminating the need of memory defragmentation.

Perforated design consists of two major components: Extended page table for extra level of mapping, and a modified L2
TLB organization and lookup protocol. We discuss these two in the following paragraphs.

In order to map 4KB pages within a 2MB huge page, an extra level of page table entry must be added below the 2MB table
entry. In addition, the page table must also contain information to identify which aligned 4KB address ranges are 
individually mapped as "holes". Both information must be easily located since they are on the critical path of 
page table walks. The paper proposes that the extra level of indirection can be located right next to the main
page table, and calls it "shadow page table". When initializing a page table for perforated pages, the OS should
allocate two pages, instead of one, when creating the page table entry. The shadow table entry has the same format
as a last-level page table entry for mapping 4KB pages, with the same layout for base address and permission bits.

