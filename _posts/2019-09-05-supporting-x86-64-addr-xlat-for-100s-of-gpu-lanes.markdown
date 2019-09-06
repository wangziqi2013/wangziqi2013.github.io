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

**Highlight:**

1. Impressive performance achievemnt with simple observations and solutions. 

2. The design of sharing the page table is a significant improvement over IOMMU-based, separate page table design.
   Page faults can be handled by the OS in the address space of the GPU driver without modifying the memory
   manegement part of the OS.

**Lowlight:**

1. This paper does not mention how the CR3 is obtained by the GPU. For example, on a context switch, the content of
   CR3 is overwritten, and GPU cannot perform address translation if it does not have a cached copy. 

2. The paper should mention that memory coalescing works slightly different for VA and PA. If the TLB is before the 
   coalescer, then coalescer can use PA to perform coalescing, which can potentially be more optimized since it 
   could reorder memory accesses to increase row buffer hit rate. If, however, the coalescer only sees VA, then there
   is no such knowledge to be leveraged and access to DRAM may be slightly slower. This effect can be trivial, though,
   because the OS tends to map consecutive virtual pages to consecutive physical frames.


This paper explores the design choice of equipping GPUs with a memory manegement unit (MMU) in order for them to access
memory with virtual addresses. Allowing GPU and CPU to co-exist under the same virtual address space is critical to
the performance of GPU applications for future big-data workloads for several reasons. First, if the GPU can share storage
with CPU, data does not need to be copied to dedicated GPU memory before and after the task, which implies lower bandwidth
requirement, energy consumption and latency. Second, it also simplifies programming for GPU applications, since the programmer
can simply assume that all variables will be modified in-place by the GPU application, rather than reasoning program bahavior
with two disjoint address spaces in mind. This differs from some GPU programming
frameworks in which two copies of the input and ouput variables are maintained, and special library routines are used even
for simple tasks such as allocating memory. Lastly, with virtual addresses, the pointer
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
GPU memory requests. Second, with a page table initialized by the driver, rather than the operating system running on 
host CPU, it is either impossible to handle page faults or demand-paging, or requires significant OS enhancement.

In the following sections, we assume a baseline design of GPUs equipped with CPU-like MMU hardware. The MMU hardware
performs page walks on bahalf of the GPU using the same page table as the one used by the GPU driver. Prior to starting 
a kernel on GPU, the driver should initialize the environment including data structures in its own address space. Memory
allocation can be done as simple as using the standard malloc() or mmap() interface. In addition, each CU is extended with
a private L1 TLB. Memory requests are first handed to the L1 TLB for address translation, and then sent to the coalescer.

This paper makes three important observations which guide the design of an efficient MMU for the GPU. The first observation
is that address coalescing works equally well for virtual addresses and physical addresses. In the baseline design, 
memory addresses are first sent to the TLB for translation before they can be coalesced. This ensures that accesses to
the same cache line can be combined, and also accesses to the same DRAM row can be clustered such that the row buffer
is leveraged to provide low latency access without having to activating a different row for every access. The paper observes,
however, that this may overwhelm the TLB with bursts of memory requests, which in fact increases the latency of TLB
access. Better performance is observed if the TLB is only accessed after memory accesses are coalesced, which implies
that TLB access latency is a critical factor in the overall performance.

The second observation is that memory requests are usually generated in bursts for GPU applications as explained above.
This not only adds to the contention on the TLB, but also increases TLB miss rate significantly, due to the fact that
GPU applications have less locality to exploit by the TLB. As a result, the MMU hardware would also observe bursts of 
page walk requests generated by all per-CU TLBs, which serializes memory accesses from all CUs that are, in the best case,
supposed to be executed in parallel. The effect of access serialization can be particularly harmful for applications that
access irregular data structures (e.g. BFS) or streams data without temporal locality.