---
layout: paper-summary
title:  "An Adaptive Memory Compression Scheme for Memory Traffic Minimization in Processor-Based Systems"
date:   2020-09-05 01:58:00 -0500
categories: paper
paper_title: "An Adaptive Memory Compression Scheme for Memory Traffic Minimization in Processor-Based Systems"
paper_link: https://ieeexplore.ieee.org/abstract/document/1010595
paper_keyword: Compression; Adaptive Compression; Dictionary Encoding
paper_year: ISCAS 2002
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents an adpative memory compression scheme to reduce bandwidth usage. The paper points out that prior 
compression schemes, at the point of writing, only uses a fixed dictionary, which is obtained from static profiling, for 
compressing symbols between the LLC and the main memory. This scheme works well for embedded systems, as these systems
typically only execute a limited set of programs for fixed functions. When it comes to general purpose processors,
this will not work well, given a braoder range of programs that will be executed. 

The paper, therefore, proposes a simple compression scheme with adaptive dictionary. The basic architecture is simple:
A compression and decompression module sit between the LLC and the main memory. The paper suggests that not
all blocks in the main memory are compressed, since this will incur large metadata overhead, as the amount of metadata 
grows linearly with the size of the main memory. Instead, only a subset of blocks will be stored in compressed form
at a separate location, called the compressed memory store, in the main memory. The compressed memory store is organized
in a fully-associative manner, meaning any address can be mapped to any slot in the compressed store.
Slots in the compressed memory store are of fixed size K, which, as the paper suggests, is set to one fourth of a cache 
line size, achieving 4x bandwidth reduction if the LLC fetchs a block from the compressed store.
A fully-associative metadata cache maintains compressed store addresses for blocks that are currently in the store. 
The metadata cache is implemented as a Content-Addressable Memory (CAM), which returns the compressed block address
in the compressed store given the uncompressed physical address, if the block is truly compressed. Otherwise, it
signals a miss, indicating that the block has not yet been compressed.

On a block fetch operation, the LLC controller first checks the metadata cache using the physical address. If the block
is compressed, then the metadata cache returns the current physical address of the compressed block in the main memory,
and the LLC issues a request for a block of size K to the memory. Otherwise, if a miss is signaled, the block is, by default,
stored on its physical location. The LLC controller issues a request of the original block size to the main memory
as in a regular memory read. 

Note that the compression scheme in the paper are not to reduce main memory consumption. Instead, the design is focused 
on reducing bandwidth usage between the LLC and the main memory, at the cost of slightly more memory usage by adding a 
compressed memory store. A compressed store with the most recently accessed addresses will suffice, since a majority of 
requests to the main memory will be redirected to the compressed store, due to the locality of accesses. 

On a dirty block write operation, the LLC controller first checks the metadata cache, and meanwhile, sends the block
for compression. If the address is currently in the compressed store, and the compressed size of the block is still
less than or equal to K, then the block will be written back to the same address in the compressed store. If the block
is currently in the compressed size, but the compressed size exceeds K, it will be removed from the cache, and stored
back to its original location. If, on the other hand, the compressed size is within K, but the cache signals a miss,
one existing item will be evicted from the cache, after which the block's address is inserted. The paper suggests that
any replacement algorithm for fully-associative cache can be employed. 
When evicting an entry from the cache, the LLC controller first fetches the compressed line, decompresses it,
and writes it back to the home location.

We next describe the compression algorithms proposed by the paper. The first algorithm is a dictionary-based, adpative
algorithm that uses online profiling. The compressor and decompressor share a N-entry dictionary structure, which
is implemented as a CAM on the compressor side, and a SRAM on the decompressor side. The dictionary maps 32-bit symbols
to log2(N) bits compressed code words. At compression time, each 32-bit word is used as the lookup key to obtain the 
index of the entry, which is then written to the output stream. The compressed
