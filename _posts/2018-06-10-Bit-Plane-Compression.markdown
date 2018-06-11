---
layout: paper-summary
title:  "Bit-Plane Compression: Transforming Data for Better Compression in Many-Core Architectures"
date:   2018-06-010 16:54:00 -0500
categories: paper
paper_title: "Bit-Plane Compression: Transforming Data for Better Compression in Many-Core Architectures"
paper_link: https://ieeexplore.ieee.org/document/7551404/
paper_keyword: BPC; Compression; Bit Plane
paper_year: ISCA 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Compressing for main-memory can be beneficial as it saves both capacity and bus traffic. This paper mainly focuses 
on the latter, without presenting in a detailed manner how compressed blocks are stored and indexed in the DRAM array.
There exists several design trade-offs for memory compression architectures. For examples, designing for cache only
compression significantly differs from designing for main memory compression, because the former could employ
techniques such as re-compression and fast indexing structures with relatively low overheads, while the latter 
usually could not afford so. The compression algorithm is also of great importance to the overall system design.
Classical fixed-length encoding may be favored as they can approximate the entropic limit. The computational 
complexity on hardware, on the other hand, can be prohibitive. Variable lengthed encoding with a dictionary
could work for cache only compression, but the overhead of the dictionary when applied to the main memory can 
overshadow its benefit.

This paper proposes Bit-Plane Compression (BPC), which is specifically tuned for GPGPU. GPGPU systems benefit from
compression for two reasons. First, GPGPUs have higher demand for memory bandwidth, and is more likely to be 
memory-bound. They access data in strided pattern, with no or very little temporal locality, and limited spatial 
locality. Caching, in this case, does not provide as much benefit as in a general purpose system. Second, the workload
that GPGPU runs generally processeses data items of the same type. They are either large arrays of homogeneous 
data items, or composite types whose elements are of the same type. Homogeneous data items usually demonstrate
value locality, where adjacent items differ only by a small amount. This has been confirmed in the paper by running
GPGPU benchmarks and collecting statistics on their usage of allocated memory. All but three workloads do not have 
scala variable in global memory. 

The memory compression architecture takes advantage of value locality by storing only the first element in a chunk of 
memory unchanged as the base value. The rest of the elements are stored as the delta value from its previous element.
Thanks to the presence of value locality, these delta values are expected to be small integers, which can be encoded in
far less bits than the original data type. For example, in Base-&Delta;-Immediate (BDI) encoding, delta values are encoded 
by the hardware using 8, 16 and 32 bits in parallel, and the best scheme is chosen based on both compressibility and
compression ratio. This scheme, though works well in practice, can only achieve a compression ratio between 1.5:1 for floats 
and 2.3:1 for integers. 

Using 1-, 2-, or 4-bytes to store compressed 8 byte deltas can indeed reduce the total amount storage. They can be 
all sub-optimal, however, if the value range of the deltas can be represented by, for example, 5 bits, or 18 bits. 
In BDI, 1 byte and 4 byte encoding must be chosen. There is still a waste of storage, though, as the higher 3 and 6 bits 
in the compressed code are always zero. As long as the compression scheme stores and fetches data in an aligned manner, 
there is no way to exploit value locality at sub-byte granularity.

BPC, on the other hand, transforms the deltas to extract more information that can be compressed. It features a two-stage
processing pipeline. In the first stage, a transformation called "Delta-BitPlane-XOR" (DBX) is applied to raw data. In the 
second stage, the resulting sequence is compressed using simple schemes such as run-length encoding (RLE) and frequent
pattern encoding (FPE), and so on. The first stage compression is designed in a way such that the generated sequence will
have long sequences of zero words if deltas are small values. The length of the zero sequence is propotional to the 
number of leading zero bits which can be compressed in the delta values. We cover the process in more details in the 
next several paragraphs.

