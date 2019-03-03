---
layout: paper-summary
title:  "Log-Structured Memory for DRAM-based Storage"
date:   2019-03-03 02:11:00 -0500
categories: paper
paper_title: "Log-Structured Memory for DRAM-based Storage"
paper_link: https://www.usenix.org/conference/fast14/technical-sessions/presentation/rumble
paper_keyword: Log-Structured; NVM; Durability
paper_year: USENIX FAST 2014
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper introduces log-structured key-value store based on RAMCloud, a state-of-the-art key-value store using non-log-structured 
architecture. The paper identifies the problem with traditional memory allocators: fragmentation. The paper claims that 
traditional memory allocators such as glibc malloc() is only efficient when the application has a relatively stable DRAM
allocation pattern. If the pattern changes, a worst case of 50% space waste has been observed using synthetic workloads
on all allocators.

This paper points out that allocators can be divided into two types: non-copy allocators and copy allocators. Non-copy allocators,
such as malloc(), never moves the location of memory blocks after they are allocated. Non-copy allocator, on the other hand,
can move the location of blocks even after allocation. In practice, non-copy allocator is most likely the one used by 
general applications, because it would be impossible to move blocks around without knowing all poionter references to the block.
Non-copy allocators, however, 