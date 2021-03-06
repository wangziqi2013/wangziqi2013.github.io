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
The result of the prediction decides which size class is searched first. If the address does not have a match, then another 
class is searched. If both misses, then a page walk is initiated. The second predictor predicts whether data cache is queried,
or MMU directly searches DRAM. We hope to skip searching the data cache, because on some data-intensive workloads, the 
cache entries can be evicted frequently, leading to relatively low data cache hit rate for TLB entries. In these workloads, 
cache does not bring much benefit and can be skipped anyway. The last design choice is that POM-TLB is not strictly inclusive.
Entries can be evicted and inserted by higher level private TLBs without inserting the same entry into POM-TLB. 

Each TLB entry in POM-TLB is 16 bytes. It contains the virtual page number, physical page number, a valid bit, and attribute bits.
An address space ID and virtual machine ID are also present to distinguish address translation between different processes and virtual 
machines. DRAM is assumed to be able to burst-read 64 bytes. Four POM-TLB entries can therefore be transferred from the DRAM to 
the data cache with short latency. POM-TLB also features a four-way set associative structure. Four elements in each set is 
stored compactly within the 64 byte burst read unit. When an address translation needs to probe POM-TLB, the MMU reads 
64 bytes using the set index extracted from the virtual page number as well as the predicted page size class. Once the transfer 
finishes, a four-way comparison is performed in parallel. Only one DRAM access is issued. Each row in the DRAM is assumed to 
be 2KB, which can hold 32 sets.

The paper recommends using die-stacked DRAM to implement POM-TLB. Lower access latancy and greater potential bandwidth 
can be achieved with die-stacked DRAM. Furthermore, using POM-TLB avoids contending for memory bus bandwidth with memory instructions. 
In data-intensive workloads, memory bandwidth is sometimes oversubscribed, and often leads to performance degradation. Having 
a dedicated piece of memory on-chip for POM-TLB, on the other hand, does not aggravate this problem, because die-stacked DRAM
has its own communication channel independent from the normal memory bus.