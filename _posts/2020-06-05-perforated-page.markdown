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
while using huge pages. The first
