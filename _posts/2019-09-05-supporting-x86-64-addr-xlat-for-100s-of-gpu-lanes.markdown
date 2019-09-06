---
layout: paper-summary
title:  "Supporting x86-64 Address Translation for 100s of GPU Lanes"
date:   2019-09-05 20:49:00 -0500
categories: paper
paper_title: "Supporting x86-64 Address Translation for 100s of GPU Lanes"
paper_link: Supporting x86-64 Address Translation for 100s of GPU Lanes
paper_keyword: GPU; Paging; TLB; Virtual Memory
paper_year: HPCA 2014
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper explores the design choice of equipping GPUs with a memory manegement unit (MMU) in order for them to access
memory with virtual addresses. Allowing GPU and CPU to co-exist under the same virtual address space is critical to
the performance of GPU applications for future big-data workloads for several reasons. First, if the GPU can share storage
with CPU, data does not need to be copied to dedicated GPU memory before and after the task, which implies lower bandwidth
requirement, energy consumption and latency. Second, it also simplifies programming for GPU applications, since the programmer
can simply assume that all variables will be modified in-place by the GPU application. This differs from some GPU programming
frameworks in which two copies of the input and ouput variables are maintained. Lastly, with virtual addresses, the pointer
semantics will remain the same for GPU and CPU, which is crucial for handling pointer-based data structures, such as graph, 
on GPU. Without virtual addressing support, before sending a pointer-based data structure to GPU, a mangling process is 
executed first to pack data into a compact form and convert pointers to relative offsets. 

This paper assumes a general purpose GPU computing model which is described as follows. The GPU device consists of a cluster 
(hundreds) of computing units (CU). Each CU further consists of several (tens of) lanes, which are essentially SIMD execution 
lanes. The GPU accesses memory using memory instructions in the ISA. There are two types of memory in the GPU. The first type,
called scratchpad memory, or local memory, is a software controlled local storage for the CU to perform low latency loads
and stores, whose size is also restricted. The second type of memory, called global memory, is the address space shared
by all CUs on the device, which, in this paper's proposal, is also shared with the CPU in the system. Since all threads in
a CU execute the same instruction at the same cycle, memory accesses tend to be issued by a CU in bursts. To handle this,
each CU is equipped with a memory coalescer, which buffers memory requests from all lanes, and coalesces them into as few 
memory read requests as possible by combining two or more memory requests to the same cache line into one. To accelerate memory
access, this paper also assumes that the GPU has a per-CU L1 write-through cache, and a L2 write-back cache shared between 
all CUs.

Prioir proposals of adding virtual memory support to GPUs relies on the address translation support provided by the IOMMU
which already exists in today's system to provide memory mapped I/O. In these proposals, the IOMMU handles all address 
translation requests issued by the GPU, and returns the physical address by walking a page table initialized by the CPU
driver before the task is started. A TLB is also assumed to be present at the GPU side such that only those missing the 
TLB will actually request an expensive address translation to the IOMMU. This proposal, however, has two important flaws.
First, as we will see later, GPU memory access patterns are radically different from what one would normally expect from CPU
and other I/O devices on the system bus. This eccentric behavior of GPU programs makes IOMMU rather inefficient in handling
GPU memory requests. 