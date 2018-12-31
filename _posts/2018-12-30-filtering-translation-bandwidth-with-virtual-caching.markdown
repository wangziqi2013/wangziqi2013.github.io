---
layout: paper-summary
title:  "Filtering Translation Bandwidth with Virtual Caching"
date:   2018-12-30 23:21:00 -0500
categories: paper
paper_title: "Filtering Translation Bandwidth with Virtual Caching"
paper_link: https://dl.acm.org/citation.cfm?id=3173195
paper_keyword: Virtual Cache; TLB; GPU; Accelerator
paper_year: ASPLOS 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper seeks to reduce GPU's address translation traffic using virtual private caches. Modern GPUs work with
virtual address spaces directly to enhance programmability, as pointer-based data structures such as graphs can be 
transferred and understood without mangling and demangling. Allowing GPUs to access the virtual address space poses a 
problem: How are VAs translated to PAs without messing up with existing virtual memory framework which is tightly coupled
with the microarchitecture of the processor? 

Current design relies on IOMMU to perform address translation. IOMMU sits on the system bus and handles memory requests 
inbound and outbound the I/O devices. The IOMMU is initialized at system startup time with a standalone page table that
maps the VA used by I/O devices to PA with access permissions. In order to perform translation, I/O devices send translation
request packets carrying the VA to the IOMMU, and the latter walks the page table and returns the resulting PA. To accelerate
translation, both the GPU and the IOMMU are equipped with private TLBs. They function exactly as TLB on the processor, that is,
to provide a fast path of translation when the TLB hits and the PA can be generated within a few cycles. The IOMMU also 
has a dedicated page walk cache (PWC) which stores entries of the page table. To further improve the scalability of the design,
the IOMMU page walker is multi-threaded: At most 16 page walks can be active at the same time. 

Despite the IOMMU optimizations on both the throughput and latency of translation, this paper argues that, on common GPU 
workloads low TLB hit rate is observed. One direct consequence is that address translation has become a major performance 
bottleneck on modern GPUs. There are several reasons for this. First, the memory access pattern of GPU features large 
scatter and gather operations.

