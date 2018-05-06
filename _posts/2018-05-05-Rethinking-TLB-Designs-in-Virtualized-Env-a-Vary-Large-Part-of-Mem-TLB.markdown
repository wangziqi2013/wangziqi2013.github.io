---
layout: paper-summary
title:  "Rethinking TLB Designs in Virtualized Environments: A Very Large Part-of-Memory TLB"
date:   2018-05-05 19:27:00 -0500
categories: paper
paper_title: "Rethinking TLB Designs in Virtualized Environments: A Very Large Part-of-Memory TLB"
paper_link: https://dl.acm.org/citation.cfm?id=3080210
paper_keyword: POM-TLB
paper_year: 2017
---

This paper presents POM-TLB, a design of shared L3 TLB that resides in DRAM rather than in on-chip SRAM. 
In general, a larger TLB mainly favors virtualized workload, where a single virtual address translation 
may involve at most 24 DRAM references, known as nested or 2D page table walk (PTW).

Although accesses to DRAM are expected to be much more slower than on-chip SRAM, which is the typical place 
in which L1 TLB is implemented, three design decisions help POM-TLB
to maintain a low translation latency. This property is crucial to the overall performance, as TLB access is on
the critical path of all memory instructions. First, POM-TLB is addressable by the MMU, and is stored in the same address 
space as physical memory. This enables the data cache to accelerate accesses to most entries in the POM-TLB. As is 
shown in the evaluation section, most of the TLB accesses can be fulfilled by L2 without reading DRAM.
In addition, two predictors are implemented to optimize cache hit rate and to reduce the number of memory references.
These predictors work like simple branch direction predictors, but have only 1 bit instead of 2 (though it was mentioned 
in the paper that 2-bit saturating counter is also feasible). To deal with the problem that pages of different granularities 
can co-exist in an address space, one of the two predictors guesses the page size of the virtual address, either 4KB or 2MB.
The implementation of POM-TLB also partitions the TLB storage and maintain the two size classes in different chunks of memory.
The result of the prediction decides which size class is searched first