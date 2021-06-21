---
layout: paper-summary
title:  "Opportunistic Compression for  Direct-Mapped DRAM Caches"
date:   2021-06-21 03:00:00 -0500
categories: paper
paper_title: "Opportunistic Compression for  Direct-Mapped DRAM Caches"
paper_link: https://dl.acm.org/doi/10.1145/3240302.3240429
paper_keyword: DRAM Cache; Opportunistic Compression; Alloy Cache
paper_year: MEMSYS 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. We can store two blocks, instead of one, in a direct-mapped slot with compression;

2. To save metadata and simply the design, one of the two lines in a slot is considered as a victim, which is
   logically not present in the cache, and therefore, it must not be dirty, and it does not have any metadata bits;

3. Metadata usage can be reduced by treating co-located blocks as victim blocks, which do not need any
   metadata bits except the tag (which is stored in the data slot);

4. Compressed blocks can be stored from both ends of the data slot. The block at the higher end is stored
   in reversed bit order, such that its size need not be encoded, as it is implicitly encoded in the compressed
   format (can be computed using the compressed header);

5. FPC can be extended with stateful encoding by comparing the current word against the previous and the second
   previous word.

This paper proposes an opportunistic compression scheme for DRAM caches. The paper observes that direct-mapped DRAM
cache designs, such as the Alloy Cache, suffers from higher miss rate than conventional set-associative DRAM caches,
due to its lower associativity and the resulting possibility of cache thrashing. 
Despite the simpler access protocol and less metadata overhead, this can still hurt performance.

Prior proposals already considered compression as a way of increasing logical associativity. This, however, introduces
two issues. The first issue is that increased associativity requires more metadata bits and tags to be maintained.
Besides, the index generation function is also changed, which incurs non-trivial design changes.
Second, this somehow offsets the metadata and latency benefit of Alloy Cache, since the design goal of Alloy Cache 
is simplicity and low-latency access.

The paper is based on Alloy Cache, a DRAM cache design that features low-latency access and simple metadata
management. The Alloy Cache is direct-mapped, meaning that each address can only be stored at exactly one location
in the cache. The logical entry index (assuming a flat space) is computed by taking the modular between the 
block address and the total number of entries, which is then converted to physical row and column numbers. 
Alloy Cache stores tag and data compactly in a 72-byte entry, in which data occupies 64 bytes, the address
occupies 42 bits, and the remaining 22 bytes are be used for status bits, coherence states, and other metadata. 
No associative lookup is performed on accesses, as the tag to be checked can be instantly determined and then compared 
with the requested address. 
On either a read or write miss, the current entry is evicted, and written back if it is dirty. 
The entry is then populated with the new address and data.

This paper observes that, if two blocks can occupy the same 64-byte data slot after compression, then we can
store two blocks in the same entry, essentially increasing the associativity of the set to two, without
affecting the associativity of other sets.
This approach differs from previous proposals in the following aspects. 
First, unlike previous designs, this proposal does not maintain two copies of the metadata, and hence will not incur
extra metadata overhead, preserving the simplicity of the Alloy Cache.
Secondly, this paper does not treat both compressed blocks as first-class citizen; Instead, one of the two compressed   
blocks is treated as a clean and read-only victim block just like in a victim cache. The read-only victim block only 
responds to read misses on the other block, the fill block, and thus neither coherence state nor other metadata bits
is maintained for it.
Logically speaking, the victim block is not in the DRAM cache. It just co-locates with the fill block to reduce
the latency of block fetch if some future accesses hit the victim block.

We next describe the data and metadata layout. One extra metadata is added per-entry to indicate whether
the entry contains one single uncompressed block, or two compressed blocks, one being the fill block and the other 
being the victim block.
This bit just takes an unused metadata bit from the 8-byte tag.
In the latter case, the two compressed blocks are stored in the entry's 64-byte slot. The tag of the victim block
is stored at the beginning of the slot, which is followed by compressed fill block. The offset of the tag and the
fill block can be easily derived and therefore does not require pointers. The compressed victim block,
on the other hand, is stored in reverse bit order (i.e., the first bit of the block is the last bit of the data slot)
from the last bit of the data slot, and grows towards the other end.
The benefit of this special data layout is that no size field is needed to correctly decompress the victim block,
since the algorithm can correctly derive the size of the compressed victim block by checking its header, as we 
will see later. 
Metadata is only maintained for the fill block.

The operation of the cache is described as follows. 
When there is only one block in the slot, it is always uncompressed, and read/write requests are fulfilled just like
in Alloy Cache. When an access misses, the block is fetched from the lower level, and then compressed. If both the new
block and the old block can fit into the 64-byte slot, they will be stored such that the new block is not the fill
block, and the old block becomes the victim block. 
If the old block is dirty, it is also written back to the lower level, and all upper level sharers are recalled, i.e.,
it is equivalent to an eviction, except that the block is still stored as the victim.
If the two compressed blocks do not fit into the slot, then the victim is just evicted as in a normal cache.

When a read operation hits the victim block, the victim is logically brought into the cache and becomes the fill block, 
and the current block is logically evicted which will become the victim block. The handling of dirty current block is 
the same as in a read miss: If it is dirty, then the block will be written back. In all cases, all cached copies in the
upper level will be recalled for the current fill block.

When the upper level writes back a dirty block, if the dirty block hits the fill block, then the victim is always
evicted, and the fill block is stored uncompressed, in order to avoid the complicated case of recompression.
Writes will never hit the victim block, as victim blocks are logically not in the cache, in which case the victim
block is just evicted, and the write is performed at the lower level.

The paper also proposes a new compression algorithm called FPC-D. The algorithm processes input blocks in the
unit of 32-bit words.
It improves over the classical FPC by using 4-bit prefix instead of 3-bit prefix, supporting 16 different patterns. 
In addition, it performs simple stateful encoding (as opposed to the original FPC which is always state-less) by 
performing value matching between the current value, the previous value, and the second previous value.
This is essentially equivalent to a dictionary of size two.
The output of compression consists of a header, which is just an array of 4-bit layouts for each compressed word.
The payload for each word is stored after the header as a flat binary structure.
The compression circuit can still encode each word independently, which takes roughly 4 cycles for a single block.
The decompression circuit first computes the offset of compressed payloads using cascaded adders, and then 
decompress each word independently.
