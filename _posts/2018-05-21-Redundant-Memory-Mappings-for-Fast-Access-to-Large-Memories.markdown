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
proposes redundant memory mapping, where large chunks of mapping is represented only by a segment notation:
base, limit and offset. Permission bits are maintained on a segment basis where all pages in the segment must
have the same permission settings. The segment is also 4KB page aligned, and the size is of multiple pages