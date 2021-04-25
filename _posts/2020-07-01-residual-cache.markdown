---
layout: paper-summary
title:  "Residual Cache: A Low-Energy Low-Area L2 Architecture via Compression andd Partial Hits"
date:   2020-07-01 16:34:00 -0500
categories: paper
paper_title: "Residual Cache: A Low-Energy Low-Area L2 Architecture via Compression andd Partial Hits"
paper_link: https://dl.acm.org/doi/10.1145/2155620.2155670
paper_keyword: Cache; Compression; Residual Cache
paper_year: MICRO 2011
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Provides a new perspective that 2:1 compressed lines can be treated as a norm such that the cache only provides
   storage to these lines, and that those above 2:1 are exceptions and relative rare such that they can be treated
   differently by having a small residue cache

**Questions**

1. Writing quality and presentation of ideas are extremely low.

2. The original paper seems to suggest that the first 32 bytes of a full line be stored in the conventional LLC.
   This, however, artificially biases against the higher 32 bytes, since accesses to these 32 bytes will always 
   be misses. One of the solutions is to interleave words from the two halves based on the address of the block
   to "randomize" offset of words that are always present.

3. The paper does not seem to give a correct description of the tagging scheme of the residual cache. If the location
   in the LLC is used, the tagging should consist of higher bits of the index plus the way number in the LLC set.
   The paper also mentions higher index bits.

4. The paper mentions that critical words can be delivered first, but L1 will almost always request a full cache line
   rather than a certain word. I understand you can extend the MSHR with the word offset of the request, but eventually
   the full line must be sent to the L1. Do you do that in the background and deliver the line to L1 later (which 
   involves complicated corner cases), or partial hits are simply uncachable?

This paper proposes residual cache, a LLC design that features lower area and power overhead compared with conventional
set-associative caches. This paper points out that as the size of the LLC increases, the resulting higher power consumption
and area overhead can be problematic for mobile platforms. Reducing the cache size, on the other hand, may allievate 
these issues, but they increase execution time due to a less effective cache hierarchy, which also negatively impacts
power and performance.

This paper seeks a method to reduce the physical size of LLC without sacrificing performance. The observation made by 
the paper is that cache compression is effective in reducing the size of cache blocks, achieving a 2:1 or higher 
compression ratio in most cases. Based on this observation, the paper proposes that each physical line in the conventional
LLC be only half of the logical size, cutting the size of data banks, and the resulting power and area overhead, by half.
Cache lines that can be compressed to half of their original size are stored only within the conventional LLC, which 
is the majority of the case. In a rare case where the line is not easily compressible, an extra, smaller residual cache 
will buffer the rest of the cache line in its own data array, which is also organized into 32 byte blocks. In this 
extended architecture, access requests from the upper level may only partially hit the block stored in the conventional
part of the LLC, which qualifies for cache hits as long as the requested bytes are in the conventional cache.

We next describe the design in details. The LLC data store is divided into two parts. The first part is the conventional
part of the LLC, which still functions as a regular LLC, except that the data slot is only 32 byte per tag. Data stored
in the conventional part of the LLC can be either a compressed line whose size is smaller than 32 bytes or 32 bytes from 
a full cache line. Note that in the latter cases, values are stored in an
"interleaved" manner, instead of sequentially, to avoid artificially biasing against the last 32 bytes of a block.
The interleaving pattern may also change based on the address to avoid biasing against odd and even numbered words.
(**Note: The paper does not explicitly have this, but I do think it is critical in the design**).
The second part is the residual cache, which stores the remaining 32 bytes of a partial cache line, if it cannot be 
compressed to less than 32 bytes. The residual cache is significantly smaller than the conventional cache to avoid the 
same power and area overhead. The residual cache is also organized as a set-associative cache. Instead of being accessed
using the address of the requested block, the residual cache is addressed by the location of a block in the conventional 
LLC, which consists of a set number and way number. The paper suggests that the lower bits of the conventional LLC index
be used as the index to the residual cache (since the size of the residual cache is smaller), and the rest be used as the 
tag. Both caches run independent eviction algorithms, but when the conventional LLC evicts a block, the residual block,
if any, should also be evicted from the residual cache. Residual cache evictions do not require the conventional LLC
to also evict the block, though.

A logical cache block can be stored in one of the two states: (1) Compressed and only stored in conventional LLC; 
(2) Uncompressed and stored in both caches. In the former case, the 
compression metadata is stored in an extra hardware structure called the encoding cache. Although the paper does not
cover the details of the encoding cache, it can be inferred from the text that each 32 bit words require 2 bits of 
metadata for representing its compression status. The encoding cache is only accessed when compression and decompression
is involved. The encoding cache has the same organization of the conventional LLC, such that entries in the LLC can be
statically one-to-one mapped to the encoding cache. (**Note: It would be more natural to just say that the LLC tags
are extended with an extra 2-byte field.**)

On a read request, the conventional cache and the encoding cache are accessed in parallel. If the conventional LLC
signals a hit, and the metadata indicates that the line is compressed to less than 32 bytes, then the data array is 
accessed, after which the line content is decompressed. If metadata bits suggest that the line is uncompressed, then 
the residual cache is probed with the location of the slot that gets hit. If the residual cache also signals a hit,
then the two halves of the uncompressed cache line are recovered by reading the data array of the residual cache
and then weaving the interleaved words back the original order. A miss from the redicual cache in this case does not
necessarily indicate an access miss. The cache hierarchy can still return the critical word to the pipeline if
the word exists in the conventional LLC. Whether or not the full cache line is installed into the L1 is implementation
dependent, though.
If the conventional LLC signals a miss, then the full cache line is read from the DRAM. A compression will first be 
attempted once the DRAM access completes. If the compression is successful, i.e. the line can be compressed to less 
than 32 bytes, then it is installed to the conventional LLC after evicting an existing block. If compression fails,
then the line will be stored uncompressed in both conventional LLC and the residual cache. An eviction is also made
from the residual cache to make space for the new half.

On a write request from the upper level, the block is also compressed. This process is similar to the line fill as 
described above, except that it is possible that an older version of the line already exists. In this case, the 
size of the old version and the size of the new block after compression is compared. If both are uncompressed or smaller
than 32 bytes, the new version can be directly installed. Otherwise, one block needs to be evicted from the residual 
cache or simply freed, to accommodate for the size change.

The paper also proposes a low latency compression and decompression circuit prototype. The prototype algorithm consists
of three stages, which can be pipelined to further improve throughput. In the first stage, comparators check each of 
the 32 bit words in the cache line for high bit 1's or 0's. These patterns indicate small positive or negative values,
which can be stored with less bits. The outcome of the comparison is carried to the next stage. In the next stage, the 
words are shifted by shifters in parallel to remove high bit 1's or 0's, if the comparator indicates so. Otherwise they
will be unchanged. In the last stage, the compressed words are gathered, and the final size is measured. If the size is
larger than 32 bytes, then compression fails, and the original block is output. If the final size is smaller 
than 32 bytes, compression succeeds, and the compressed line is stored in the conventional LLC's data slot only. 
The encoding cache is also updated with the compression metadata of each individual word.
Decompression works the same, except that the pipeline stages are reversed. The compressed words and encoding metadata
are first read out, then the shift amount is generated, and finally shifted by shifter array. The paper suggests that
the circuit that generates shift amount and the shift array can be shared between the encoder and decoder, since they
function identically in both directions.

It should also be noted that the compression algorithm is made really simple to reduce compression and decompression 
latency, as only small integers are compressed to a shorter form. In addition, no further attempt will be made if the 
compression algorithm could reduce the size of a block by half, since there is no direct benefit of storing a smaller
cache line while it is already less than 32 bytes. The algorithm also does not seek a compression ratio lower than 2:1,
since it is simply a compression failure which does not contribute to runtime energy reduction.