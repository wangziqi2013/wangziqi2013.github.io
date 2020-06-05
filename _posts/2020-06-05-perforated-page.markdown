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
serve two differeit purposes. First, virtual address holes do not need to be backed by any physical pages. If a hole
is known to be never accessed by the application, the physical page backing the hole can be released, which increases
memory utilization.
