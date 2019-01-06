---
layout: paper-summary
title:  "Translation-Triggered Prefetching"
date:   2019-01-05 23:59:00 -0500
categories: paper
paper_title: "Translation-Triggered Prefetching"
paper_link: https://dl.acm.org/citation.cfm?id=3037705
paper_keyword: TLB; Prefetching; DRAM
paper_year: ASPLOS 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes TEMPO, an automatic prefetching scheme driven by TLB misses. Modern big-data workloads, unlike classical
scientific computation, demonstrates less locality and hence exhibits higher TLB misses. There are several causes of decreased
locality, such as graph workloads where nodes are linked by pointers; sparse data structures where non-adjacent entries are 
stored in noncontiguous blocks of memory, and large memory workloads where the amount of translation information is just too
large to be cached entirely in the TLB, causing TLB thrashing. When TLB miss happens, the page walker must load the PTE entry from
the main memory into TLB, and then replay the memory access instruction, which will hit the TLB. One important observation made
by the paper is that a large fraction of TLB misses are actually followed by cache misses. This is because TLB misses are often
indicators of the fact that the target physical address is cold and has not been touched for a while. In such cases, it is
reasonable to expect that the cache does not contain the target block.

Based on this observation, TEMPO attempts to mitigate the "double miss" problem by prefetching the target memory address when
the last level TLB entry is read from the DRAM. The approach is described as follows. When a TLB miss is detected, the page walker
initiates the page walk process. 