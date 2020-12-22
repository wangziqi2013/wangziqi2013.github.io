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
On the first level, the GPU's main memory stores most of the compressed lines in fix sized slots, which fulfills most
of the accesses to compressed data.
On the second level, if a compressed line cannot be entirely stored by a fix sized slot, the rest of the line will then
be stored in a secondary storage which is connected to the GPGPU via high bandwidth links.
A request to such cache lines will be fulfilled by both the GPGPU's main memory, and the secondary storage. The 
compressed line can only be decompressed after both parts have been fetched.
