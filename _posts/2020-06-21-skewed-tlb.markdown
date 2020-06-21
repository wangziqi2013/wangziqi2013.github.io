---
layout: paper-summary
title:  "Concurrent Support of Multiple Page Sizes On A Skewed Associative TLB"
date:   2020-06-21 05:29:00 -0500
categories: paper
paper_title: "Concurrent Support of Multiple Page Sizes On A Skewed Associative TLB"
paper_link: https://dl.acm.org/doi/10.1109/TC.2004.21
paper_keyword: Skewed TLB; TLB
paper_year: Technical Report 2003
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This technical report proposes a noval TLB design, skewed associative TLB, in order to support multiple page sizes
with a unified TLB. MMU nowadays support multiple granularities of page mapping, with page sizes ranging from a few KBs 
to a few GBs. This introduces the problem of correctly finding the translation entry given a virtual address, since the 
page size of the address is unknown before the entry is found. In conventional set-associative TLBs of only one page 
size, the lowest bits from the page number of the requested virtual address is extracted as the set index. 
The virtual page number is easily from the requested address, since the page size is fixed. For TLBs with multiple 
page sizes, since the lowest few bits of the page number itself is a function of page size, using these bits as the 
set index is infeasible.


