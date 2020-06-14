---
layout: paper-summary
title:  "Skewed Compressed Caches"
date:   2020-06-13 22:27:00 -0500
categories: paper
paper_title: "Skewed Compressed Caches"
paper_link: https://dl.acm.org/doi/10.1109/MICRO.2014.41
paper_keyword: Compression; Cache Tags; Skewed Cache
paper_year: MICRO 2014
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. Using super block tags while allowing the same tag be used in different way groups and even in the same way

This paper proposes skewed compressed cache, a compressed cache design that features skewed set and way selection.
The paper identifies three major challenges of designing a compressed cache architecture. The first challenge is to
store compressed blocks compacted in the fixed size physical slot. Since compressed block sizes could vary significantly
based on the data pattern, sub-optimal placement of compressed data will result in loss of effective cache size and 
more frequent compaction operation on the data slot. The second challenge is to minimize the number of tags while making
the best use of the physical storage. In the conventional scheme where each tag could only map one logical block, 
designers often have to over-provision tags to enable storing more logical blocks in the cache, which also increases
area and power consumption. The third challenge is to correctly locate the compressed block in the physical storage,
since on compressed architectures, blocks are not necessarily stored on a pre-defined size boundary, which must be
explicitly coded into the tag as well. In addition, the associativity between tags and physical slots are often more
flexible to enable one tag to map any or a subset of segments (assuming segmented cache design) in the current set.

In order to solve these challenges, the paper noted that two types of locality exist in the majority of the workloads.
Spatial locality exists such that adjacent address blocks are often brought into the LLC by near-by instructions, which
are also cached in the LLC at the same time. Meanwhile, these adjacent blocks are also tend to be compressed into similar
sizes, due to the usage of arrays and/or data structures containing small integers, etc.
These two observations, combined together, suggest that blocks that are adjacent to each other could be cached with little
tag and external fragmentation overhead, since one tag plus an implicit offset is sufficient to generate the address of 
a block, similar to address computation in sector caches. In addition, adjacent blocks can be stored compactly without 
worrying too much about physical storage management, since they can just be classifyed into one uniform size, and be 
naively stored as fixed size blocks.

Based on the above conclusion, the paper proposes a tag mapping scheme with super blocks. Instead of only mapping one 
block per tag, the tag now maps a few consecutive and aligned regular blocks in the address space, called a super block.
Tags and physical 64 byte slots are still statically, one-to-one mapped, to enable fast access of both tag and data.
Note that not all blocks within the super block are necessarily present at the same time. In fact, with compression
applied, it is possible that a few compressed blocks in the super block share the same physical block.
To further simplify address mapping within the physical slot (i.e. how to find starting and ending bytes of blocks),
the paper assumes that each super block tag has a compression factor (CF), which determines the size of the compressed blocks
stored in the physical slot. The cache controller, once has inferred the CF, which is implicitly coded in the address tag 
(see below on how), just treats the physical slot's content as fixed size blocks, and access compressed blocks at static 
offsets. To describe which blocks are present in the cache, each super block has a vector of block status, including coherence
states, valid bits, etc., for potentially all blocks in the super block.
If a valid bit is on, the block is considered as present, which are stored in-order (i.e. the order compressed blocks
are stored is consistent with the order suggested by the bit vector) in the physical slot.
The paper uses a super block size of eight.

This paper also borrows the skewed cache design in uncompressed caches. The original idea skewed cache is based on the 
fact that real-world workloads often do not distribute accesses evenly too all sets, underutilizing some sets while 
incurring excessive conflict misses on some other sets. To reduce conflict misses, the skew cache design proposes that
the cache be partitioned into equally sized ways, and that different hash functions be used on different ways to locate
the tag. By using different hash functions, the "conflict with" relation is no longer transitive: In the regular cache
design, if address A, B conflict on set X, and B, C also conflict on set X, then A, C will always conflict on the 
same set. This is no longer true in a skewed cache, since each way now has its own conflict relation. Two addresses
conflicting on way W1 does not necessarily suggest that they also conflict on way W2, thus guaranteeing addresses
that will be conflicts with each other in a regular set-associative cache being unlikely to conflict, resulting in
higher cache hit ratio. 

The skewed compressed cache, overall, demonstrates skewness on three levels. On the first level, it partitions a 
highly-associative LLC (e.g. 16 ways) into a few different way groups (4 in the paper), and also classifies compressed 
blocks into four compression factors (CF): 0, 1, 2, 3. Blocks that are uncompressible are in CF0; Blocks that can be compressed
to between 1/2 and 1/4 of the original size are in CF1; Blocks that can be compressed to between 1/4 and 1/8 of the original
size are in CF2; Blocks that can be compressed to under 1/8 of the original size are in CF3. For any given address, 
it can only be stored within one of the four ways groups, depending on its CF. If the address tag is found in a CF,
then the cache controller can immeidately infer the CF of the address tag, and interpret the layout of the data slot based
on the CF: For CF value of k, the data slot will be interpreted as having 2^k segments, eaching hosting a compressed
block indicated by the valid bit vector of the tag.
The skewness on CF breaks one of the most important invariants in conventional caches that an address tag can
only appear at most once in the tag array at all times. 
With super block and CF-based group selection, one address tag can appear in several locations. 
Compared with convention designs, in which a super block is at most bound to all segments within the set at a considerable
metadata cost, this arrangement increases the number of possible locations a super block be stored in the cache, while 
keeping the slot address mapping and space managment simple and intuitive.
Note that

The second level of skewness comes from the fact that blocks from the same super block can also be hashed to different 
set indices, even in a way group. This further increases the number of possible locations compressed blocks from a super 
block could be stored.
Recall that adjacent blocks often demonstrate similar compressibility. The hashing scheme is designed to generate the
same index for blocks that are adjacent to each other, to maximize the chance that the full 64 physical slot on that
index be fully utilized, since blocks of the same CF on the same super block are always hashed into the same way group.
Blocks with different CFs also use different hash functions. For CF0 blocks, the hash function takes the tag bits 
(i.e. all bits above the block offset expect the lowest 2, which will be used for way group selection; see below) and 
all three block offset bits in the requested address to generate the set index, since these blocks cannot be compressed,
and must not be hashed to the same index (will be a conflict otherwise).
For CF1 blocks, each adjacent two of them in the super block should be hashed to the same index, while all others should
be to different sets. The hash function, therefore, takes the upper two bits of the block offset and the super block tag,
indicating that adjacent two blocks (aligned) will always be hashed to the same index, since these blocks only differ in
the lowest bit of the block offset.
For CF2 blocks, the hash function takes the highest one bit and the super block tag, since four such blocks could fit into
the same 64 byte physical slot, and every adjacent four (i.e. upper and lower half of the super block) will be hashed to
the same index this way. Lastly, for CF3 blocks, the hash function ignores the block offset bits, indicating that all of
them will always be hashed to the same index.

The last level of skewness lies in the fact that different hash functions can be used for each way in a way group (
the previously discussed hash functions are applied to only a single way). By using a per-way hash function, addresses
that conflict with each other could now be scattered on different indices on different ways, further reducing conflicts.

Cache accesses are performed as follows. If the access is a read, the cache controller computes the CF of the address
on each way group by taking the XOR of the two loest bit of the block tag and the way group index (0 - 3 in our case).
Then the set index on each way of the way group is computed in parallel using the CF of each way group, and the rest
of the bits in the requested address.
A cache hit is signaled, if (1) The super block tag matches the requested address; (2) the corresponding valid bit is set
for the block index in the requested address in one of these matching tags. The physical slot is then accessed and data
is read out using the 
