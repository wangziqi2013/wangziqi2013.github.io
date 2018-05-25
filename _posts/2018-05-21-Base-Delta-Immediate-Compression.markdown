---
layout: paper-summary
title:  "Base-Delta-Immediate Compression: Practical Data Compression for On-Chip Caches"
date:   2018-05-21 22:47:00 -0500
categories: paper
paper_title: "Base-Delta-Immediate Compression: Practical Data Compression for On-Chip Caches"
paper_link: https://dl.acm.org/citation.cfm?id=2370870
paper_keyword: Cache Compression; Delta Encoding
paper_year: PACT 2012
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes an simple and yet effective cache compression architecture. Compressing cache lines 
for L2 cache and LLC increases effective cache associativity, reducing conflict misses. To store the compressed 
cache line, the paper proposes doubling the number of tags in each set. This design allows at most two cache lines to
be stored compactly inside a 64 byte line while maintaining the number of data storage unchanged. Since the majority of 
the resources of the cache system are devoted to data storage, only doubling the size of the tag array has a minimum
effect. Power consumption, however, can become worse, as the comparator used for comparing tags must also be doubled.

To reduce the negative effect of increased load and store latency, compression is only applied to shared L2 and L3 caches,
but not L1. The priority should be put on decompression, as it is usually on the critical path of load instructions. 
In contrast, decompression can usually be performed on the background after the critical word is supplied to the processor.

Two compression algorithms are proposed and evaluated by the paper. The fundamental idea behind these two algorithms is 
based on the observation that an integer usually only stores values within a narrow range. For example, an array of 
pointers usually point to addresses of a certain class, from the same allocator, inside an array, etc. An array of integers 
are often small values that can be represented using only a few bits. For the former, if an appropriate base value is 
chosen, the remainder of them can be represented as the difference with that base value, which are potentially smaller. 
Fewer bits can be used to encode such a sequence, reducing the number of bits used to store the cache line. 

The first algorithm, B+&Delta;, only takes advantage of narrow values. The algorithm assumes that the input cache line 
consists of values that are within a narrow range. It tries to find a base, with which the remainder of the line could 
be compressed using fewer bits. The base is stored first in the compressed cache line, and then follows the delta, in 2's 
complement form (as the delta could be negative). We restrict that the number of bits in delta values must be 
uniform, such that a hardware circuit can easily decode all values in parallel without having to guess the boundary
of the deltas, as in some other algorithms. For simplicity, The base value is chosen as the first value in the cache line.

The second algorithm, B&Delta;I, extends the B+&Delta; algorithm by using zero as the second base. Generally speaking,
adding a second base could potentially increase the compression ratio, because the number of bits required by deltas can 
be further reduced by clever choices of the two bases. This, however, overcomplicates the hardware design, because the 
circuit now must ensure that the two base values are chosen property. To avoid such complication, the B&Delta;I scheme
implicitly chose zero as the second base. Small integers, such as counters, array indices, etc., can be encoded with fewer 
bits with zero being the second base. The "I" in B&Delta;I stands for "Immediates", which is just a fancy name for integer 
constants in assembly.

The encoder circuit is designed as follows. The encoder has two parameters. The input length *k* defines on which granularity
does the encoder perform delta operation between the base (the first k-byte word in the cache lines) and other k-byte words.
The output length *j* defines the number of bits in the output delta. If one or more *k* byte deltas cannot be encoded into an integer 
of length *j*, then the encoder outputs "No" via a signal line. Otherwise, it outputs the compression ratio. By changing values of
*k* and *j*, different encoders can be built. In the paper, it is recommended that at least we should have (8, 4), (8, 2), (8, 1),
(4, 2), (4, 1) and (2, 1) combination for (*k*, *j*). Further, one zero encoder and one repeated value encoder are added
to handle special cases. The tag arrays of L2 and L3 are extended with three extra bits. These three bits identify the encoding 
algorithm used for compressing the cache line. At decode time, the decoder performs decode operations based on the three 
"encoding algorithm" bits. The decoder simply takes the base and adds the sign-extended 2's complement onto every delta and produces
the decompressed cache line.

When a cache line is brounght into the L2 cache or written from the higher level, it needs to be compressed by the cache controller.
The cache controller consists of all hardware encoders of different input and output parameters running in parallel. A special priority 
decoder selects the scheme with the highest compression ratio. The resulting compressed line is then written into the 64 byte data 
storage together with its tag.

If B&Delta;I is used for compression, the process is divided into two stages. In the first stage, the circuit finds out smaller 
values and compresses them using fewer bits. The locations of values that have been compressed are represented using a bit mask.
Then in the second stage, the circuit selectively compresses only values on those locations where the bit is clear. The first 
location with a clear bit will be chosen as the base value. 