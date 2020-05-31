---
layout: paper-summary
title:  "A Robust Main-Memory Compression Scheme"
date:   2020-05-31 11:36:00 -0500
categories: paper
paper_title: "A Robust Main-Memory Compression Scheme"
paper_link: https://dl.acm.org/doi/10.1109/ISCA.2005.6
paper_keyword: Compression; Paging
paper_year: ISCA 2005
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes a simple but yet efficient main memory compression scheme. The proposed scheme is meant to be general
enough to be applied to any system with minimum application level modification, and also efficient for space saving
under the current virtual memory framework. The paper identifies three major challenges of designing a main memory 
compression scheme. First, decompression is on the critical path, since the processor has to stall the read uop to
wait for the decompression to complete. Compression, on the other hand, is only triggered when a line is evicted,
which can often be performed on the background. Second, a compressed main memory no longer maps virtual addresses to
physical addresses linearly within a page. The mapping depends on both the compressibility of the page and the 
placement policy as well as page layout. This inevitably adds more metadata to maintain for each page. A carefully 
designed compression scheme should prevent these metadata from incurring extra memory bandwidth and/or occupying too
much on-chip space. The last challenge is that compressed pages or blocks may not always be stored compactly within
a page. Fragmentation is always a concern when both blocks and pages are variably sized, which reduces the efficiency
of space saving and complicates OS storage management. 

To solve the first challenge, the paper observes that in some cases, a number of cache lines are just filled with zeros,
which makes them a perfect candidate for highly efficient compression. Besides, frequent pattern compression (FPC) also
works pretty well on most of the workloads. Compared with more complicated, directory-based schemes, using a variant 
of FPC optimized for zero-compression has the following benefits. 
