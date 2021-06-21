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

We next describe the operations of opportunistic compression. One extra metadata is added per-entry to indicate whether
the entry contains one single uncompressed block, or two compressed blocks, one being the fill block and the other 
being the victim block.
In the latter case, the two compressed blocks are stored in the entry's 64-byte slot. The tag of the victim block
is stored at the beginning of the slot, which is followed by compressed fill block. The offset of the tag and the
fill block can be easily derived and therefore does not require pointers. The compressed victim block,
on the other hand, is stored in reverse bit order (i.e., the first bit of the block is the last bit of the data slot)
from the last bit of the data slot, and grows towards the other end.
The benefit of this special data layout is that no size field is needed to correctly decompress the victim block,
since the algorithm can correctly derive the size of the compressed victim block by checking its header, as we 
will see later.
