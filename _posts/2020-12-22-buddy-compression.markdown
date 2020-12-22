---
layout: paper-summary
title:  "Buddy Compression: Enabling Large Memory for Deep Learning and HPC Workloads on GPU"
date:   2020-12-22 09:28:00 -0500
categories: paper
paper_title: "Buddy Compression: Enabling Large Memory for Deep Learning and HPC Workloads on GPU"
paper_link: https://ieeexplore.ieee.org/document/9138915
paper_keyword: Compression; GPU Compression Buddy Compression
paper_year: ISCA 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Buddy Compression, a GPGPU main memory compression scheme for simplicity and effectiveness.
The paper is motived by the fact that modern GPU workload sizes often exceed the maximum possible memory size 
of the GPU device, while the latter is difficult to scale due to physical constraints.
Conventional GPU compression schemes, however, are typically only designed for bandwidth saving but not storage 
reduction, since main memory compression most likely will produce variably sized pages, which are difficult to
handle on GPGPUs due to lack of an OS and frequent page movement.

Buddy compression, on the other hand, is the first ever GPGPU compression design that explores the aspect of bandwidth
saving. The design relies on a two-level storage hierarchy and an opportunistic storage policy. 
On the first level, the GPU's main memory stores most of the compressed lines in fix sized slots, the length of which
is smaller than an uncompressed line. Most of the accesses to compressed data are fulfilled solely by these slots.
On the second level, if a compressed line cannot be entirely stored by a fix sized slot, the rest of the line will then
be stored in a secondary storage which is connected to the GPGPU via high bandwidth links.
A request to such cache lines will be fulfilled by both the GPGPU's main memory, and the secondary storage. The 
compressed line can only be decompressed after both parts have been fetched.

The paper assumes the following architectures. The GPGPU has a cache line size of 256 bytes, and page sizes varying from
64KB to 2MB. The cache line and page size of the host CPU does not matter. 
The GPU devide has its own local main memory, which has higher bandwidth, but is limited in size.
The off-board memory, on the contrary, is large, but can only be accessed via an external high bandwidth link, which
has higher latency and relatively lower bandwidth.
The paper does not restrict the external memory to be CPU-managed host memory, or individual memory modules, as long
as they can be addressed and accessed by the GPU's MMU.

Buddy Compression requires the following hardware changes. First, since cache lines are compressed, each cache line
slot will be smaller, which changes the addressing scheme of GPGPU's main memory. Given a fixed slot size of X,
the physical address for line ID i will be i * X, rather than i * 256. Second, the GPU's MMU contains a register 
holding the address of the secondary storage's base address where the overflow area begins. The overflow area is an
allocated, continuous chunk of memory in the secondary level storage for holding overflowed parts of the line, as we
will see later. Lastly, the GPU device memory should reserve four bits per logical line in the compressed address space
to remember the compressed size of the line. The memory controller needs to access the metadata first before deciding
the address translation scheme. In the baseline design, the compression ratio is a fixed value for all lines in the
compressed address space, and should be determined before system startup. In addition, there is no per-page offset
to the overflow area, as the address mapping is just one-by-one and linear.

At startup time, the GPU's firmware initializes parameters of the compression scheme. The most important compression
parameter is the compression ratio. Given a compression ratio of R, the compressed address space has a total size
of R * S, where S is the size of the uncompressed address space. In other words, Buddy Compression simply reduces
the size of each physical slot by R times, and maps compressed lines to these slots as in the uncompressed design.


