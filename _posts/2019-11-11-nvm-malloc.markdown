---
layout: paper-summary
title:  "nvm_malloc: Memory Allocation for NVRAM"
date:   2019-11-09 17:33:00 -0500
categories: paper
paper_title: "nvm_malloc: Memory Allocation for NVRAM"
paper_link: https://dblp.uni-trier.de/db/conf/vldb/adms2015.html
paper_keyword: malloc; NVM
paper_year: ADMS (VLDB workshop) 2015
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents nvm_malloc, a persistent memory allocator. The paper identifies that traditional memory allocators
designed for volatile memory are insufficient to ensure correct post-recovery execution for two reasons. First, without
proper metadata synchronization and post-crash recovery, memory blocks allocated to application programs might still be 
tracked as free memory after recovery, which results in data corruption as the same block can be allocated to fulfill
another memory request, causing unexpected data race. Second, 