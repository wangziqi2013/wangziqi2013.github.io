---
layout: paper-summary
title:  "Lossless and Lossy Memory I/O Link Compression for Improving Performance of GPGPU Workloads"
date:   2020-07-19 20:01:00 -0500
categories: paper
paper_title: "Lossless and Lossy Memory I/O Link Compression for Improving Performance of GPGPU Workloads"
paper_link: https://dl.acm.org/doi/10.1145/2370816.2370864
paper_keyword: Compression; Memory Compression; GPGPU; Floating Number Compression
paper_year: PACT 2012
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes adding memory compression to GPGPU memory architecture for improving performance with reduced bandwidth 
consumption. Although many previous publications focus on saving storage and providing larger effective memory, this paper
explores another aspect of memory compression: Saving memory bandwidth for memory-bound GPGPU workloads. The paper points
out that GPU workloads often have better compressibility than CPU workloads for two reasons. First, GPGPUs are designed
to process input data in a massively parallel manner, with the same "kernel". The input data, therefore, is usually 
arrays of integers or floating point numbers of the same type, which can be easily compressed. In addition, real-world
workloads observe high degrees of locality, further enabling highly efficient compression. Second, GPGPU architectures
execute a kernel in SIMT manner, spawning multiple hardware threads sharing the same set of control signals and SIMD data 
path. Multiple memory access requests may be generated per memory operation in the kernel, since all threads in the SIMT 
architecture execute the same instruction. As a result, GPGPU designers tend to use larger block sizes to amortize the 
cost of block fetching with high access locality of the threads. For example, the simulated platform of this paper uses
an architecture with 32 threads per warp. Assuming 4-byte access granularity per thread, and highly regular access pattern
(e.g. all threads' accesses are in a consecutive chunk of memory), the memory controller will need to fetch a 128-byte
block to satisfy all memory operations within one DRAM access. Larger blocks, as pointed out by previous papers also,
are more prone to yield higher compressibility, which is ideal for memory compression.

This paper assumes a basic GPGPU workflow as follows. First, before a kernel can be invoked on a GPU, the CPU should
first prepare the data structures needed for the computation in the main memory. After that, data is transferred to the 
GPU by calling CUDA routines with the size of the structure. The GPU will use its DMA controller to move data from the 
main memory to its own memory (GDDR as suggested in the paper). After computation, the GPU moves the results back to the 
CPU using DMA.
The GPGPU has four distinct address spaces: Global, texture, constant, and local. The global address space acts similar
to the main memory such that all GPGPU threads can access it. Texture and constant address spaces are optimized for
special purposes such as textures and constant values. The local address space is only addressable to a subset of cores,
and is used for register spilling and local computation. The paper's proposed optimization only applies to global
and texture address space.

leverages the above observations to build a memory compression
