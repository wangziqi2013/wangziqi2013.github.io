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

**Highlight:**

1. Speculatively fetching a block in full size when cache miss happens. In fact if the paper has statistics on average
   size of compressed block on cache misses, it can only fetch the first few chunks, and decide whether to fetch the
   rest if the actual number of higher.

**Questions**

1. I don't get why decompression algorithm needs the size of a block? I think most compression algorithm has the size 
   after compression implied in the compression header? Or at least you can always figure out that implicitly during
   decompression?
   I am asking this because even if you have the size, it is on 16 byte granularity. The actual compressed size should
   be precise in bit unit. So even if some peculiar algorithm does need that number, having a number rounded to 16 bytes
   would help very little, I guess.

2. If lossy and loseless compression are both applied for floating point numbers, that memory region should store
   compression metadata for both compression types, which requires more bits. How does the hardware map such a 
   special area?

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
The GPGPU memory is assumed to be GDDR3, with a data bus width of 4 bytes, and a burst length of four, meaning 16 bytes
of data can be transferred per burst. Note that since the burst length of GDDR3 is fixed, at least 16 bytes of data are
read from the memory for each memory access, which is also used as the basic unit of transmitting compressed cache lines,
as we will see below.
Several memory controllers may be present on the GPGPU device, each responsible for a partition of the addressable memory. 
Each memory controller implements an instance of compression and decompression hardware. Multiple instances per controller 
provides very little improvement as compression and decompression is not the bottleneck. 
The compression and decompression algorithms are not specified, though.

Compression is performed when data is initially copied to the GPGPU memory, and when they are written back from GPU
threads. Similarly, data is decompressed when read from the GPGPU memory, and when they are copied back to the CPU
memory. The main purpose of this paper is to optimize bandwidth usage with compressed data, and therefore, data
compression does not change the home location of blocks, but only their sizes. 
To determine the number of reads required before actually generating memory read signals, the memory controller needs
to know the compressed size of the 128-byte block to be accessed. To this end, the controller reserves 4 bits per block
serving as block metadata, which stores the number of 16-bit transfers needed to fetch the compressed block.
This number can range from zero (no data is actually transferred over the bus, and zero is returned) to eight (meaning
uncompressed block). If a block is larger than 128 bytes after compression, then it is simply stored as uncompressed
to avoid overflowing to the next block. 
Before a block can be read in compressed form, the metadata entry is first read from the memory, and then the specific
number of read operations are performed to fetch the line.

The baseline design above suffers from severe performance degradation, since (1) memory access latency becomes at least
twice as large as before, since every memory access incurs another access to the metadata; (2) Extra traffic is dedicated
to fetching the metadata block from the memory. To solve this problem, the paper proposes adding a metadata cache which 
stores a few most recently used translation entries in 256 byte metadata blocks. The cache can be implemented as a small, 
fully-associative structure, since most accesses have high locality. In addition, every four bits in the cache can cover 
128 bytes of memory, resulting in a high coverage with even a small number of entries.
The paper suggests that a 32 entry cache is sufficient in most cases.

Even with a metadata cache, the access latency will still be longer than usual when cache miss happens. To reduce the 
effect of cache misses, the paper also proposes that memory controllers may issue read operations immediately on 
metadata cache misses. Since the read size is unknown, the controller always bahaves conservatively, and fetches the
full 128 byte block. Decompression, however, is still stalled until metadata bits are retrieved, since the decompression
algorithm may need the actual size of compressed block.

The paper also proposes a lossy compression algorithm for floating pointer numbers, which is also widely used in GPGPU
workloads. The observation is that some workloads do not require high precision, and the application is willing to
trade-off precision with efficiency. In addition, modern GPGPUs are already equipped with a special "Non-IEEE 754 compliant" 
mode which sacrifices precision for computation speed. 
This paper leverages this mode, and proposes that the least significant bits of 32-bit floating point numbers be truncated
when they are initially transferred and written back. 
Recall that in IEEE 754 standard, the LSB of a floating point number are lower bits of the mantissa, which are of lower
significance in determining the value of the number. 
The programmer specifies the number of bits that are to be truncated from the number when they invoke the CPU-GPU data 
transfer function, and GPGPU hardware performs the truncation and stores the after-truncation numbers in a compact form.
In addition, loseless compression can still be applied to the number after they are truncated, further reducing 
bandwidth consumption. For 32-bit floating point numbers, not transferring the lowest 8 bits can save 25% bandwidth.
This number is even higher if extra compression is applied.
The metadata bits for these area should use extra bits to indicate the number of bits truncated in order to restore
the original value.
