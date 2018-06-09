---
layout: paper-summary
title:  "Efficient virtual memory for big memory servers"
date:   2018-06-09 00:34:00 -0500
categories: paper
paper_title: "Efficient virtual memory for big memory servers"
paper_link: https://dl.acm.org/citation.cfm?doid=2485922.2485943
paper_keyword: Direct Segment; Segmentation
paper_year: ISCA 2013
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---   

This paper proposes direct segment, a segmentation based approach to virtual address
translation. The motivation of direct segment is high overhead of Translation Lookaside Buffer (TLB)
lookup on modern big-data machines. On one hand, big-data applications do not require complicated memory 
mapping. On the other hand, existing paging systems manage memory mapping for each 4 KB page separately, 
relying on a TLB to accelerate translation in most cases. The classical paging-based address mapping in this 
regard is inefficient by having both page walk overhead and redundency of memory protection bits. Based on these 
observations, direct segment is designed to eliminate paging overhead with simple hardware changes. We 
elaborate the design in the next few sections.
