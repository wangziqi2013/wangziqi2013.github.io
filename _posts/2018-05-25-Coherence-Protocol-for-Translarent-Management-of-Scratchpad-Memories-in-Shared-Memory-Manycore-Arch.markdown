---
layout: paper-summary
title:  "Coherence protocol for transparent management of scratchpad memories in shared memory manycore architectures"
date:   2018-05-25 20:20:00 -0500
categories: paper
paper_title: "Coherence protocol for transparent management of scratchpad memories in shared memory manycore architectures"
paper_link: https://dl.acm.org/citation.cfm?id=2749469.2750411
paper_keyword: Coherence; Scratchpad Memory
paper_year: ISCA 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
--- 

Scratchpad memory (SPM) is small and fast on-chip memory that allows easy accesses by applications. Compared 
with the cache hierarchy, SPM is nearly as fast, but is more power efficient. The biggest difference between
SPM and the cache is that SPM requires explicit software management in order to transfer and synchronize data,
while the cache controller manages data in cache line granularity to maintain transparent access. From one perspective,
the flexibility of programming with SPM enables the application to take advantage of application-specific knowledge
and optimize it further. On the other hand, difficulties may arise as a result of lacking coherence support 
directly from the hardware. 

This paper aims at solving the coherence problem between SPM and the memory hierarchy. The operating model of 
SPM is described as follows. In a multicore system, each core has a private SPM that is only accssible to that core. 
A DMA engine transfers data between the SPM and main memory. The application is able to issue synchronous DMA 
commands via memory-mapped I/O. Memory copies between the SPM and DRAM are not coherent. The application
is responsible to copy back dirty values to main memory. Both the virtual and physical address spaces are divided 
into conventional memory and SPM. The systems uses a few registers to inform the MMU of the address range allocated to 
SPM. The MMU perform a direct mapping from virtual address to physical address if the virtual address belongs to SPM. 
The memory controller then diverts physical addresses that are mapped to SPM to the SPM controller. 

The hybird SPM and main memory architecture works well if the data access pattern is regular and can be known 
in advance. One of the examples is HPC computing, where a dominant number of workloads access memory in a strided 
manner. The compiler is responsible for moving data between the main memory and SPM by calling into the SPM runtime 
library. Before a data structure can be accessed in the SPM, a DMA call that moves the data from main memory to
SPM is issued. After that, all references to the data structure is replaced by references to the corresponding copy
in the SPM. After the access, depending on whether the SPM copy is dirty, a second DMA transfer that copies back the 
modified data structure may also be issued by the compiler. 


