---
layout: paper-summary
title:  "Thesaurus: Efficient Cache Compression via Dynamic Clustering"
date:   2020-07-23 04:33:00 -0500
categories: paper
paper_title: "Thesaurus: Efficient Cache Compression via Dynamic Clustering"
paper_link: https://dl.acm.org/doi/10.1145/3373376.3378518
paper_keyword: Compression; Cache Compression; Fingerprint hash; 2D compression; Thesaurus
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Using content-aware fingerpring hashing to detect similar cache lines, and then use base + delta encoding to compresse.
   
2. Using start map to virtualize segment addresses. Always compacting + address virtualization enables the tag array
   to only refer to the fixed virtualized segment address which will be translated by the start map

**Questions**

1. The access latency of a base + delta line would involve in the worst case a main memory access and a data array access.
   Even in the best case there are two parallel cache accesses, one of which has to be serialized with start map access,
   and both are serialized with tag access.

This paper proposes Thesaurus, a cache compression scheme with dynamic clustering. This paper points out at the beginning
that two existing methods for increasing effective cache sizes, cache compression and deduplication, are both suboptimal
in terms of compression ratio. Cache compression tries to exploit redundancy and dynamic value range in individual
blocks or limited number of blocks using certain compression algorithms. It failed to admit inter-line redundancy or
only provides naive solutions such as compression multiple lines together as a larger block. In fact, however, many
workloads in this paper indicate that there is abundant amount of inter-line redundancy between two cache lines. These
redundancies can be encoded more efficiently as byte deltas between the two lines, which is difficult to explore with
conventional cache compression, since they only compress blocks sequentially.
On the other hand, cache deduplication removes duplicated lines using special hardware structures such as hash tables.
Incoming lines are checked with the hash table first for hash matches, and full value comparisons are conducted
later to verify if the two lines actually match. The paper argues that deduplication also failed to catch some redundencies,
since many cache lines do have identical bytes despite the fact that they are not duplications.

Thesaurus proposes dynamic cache line clustering for identifying cache lines with similar contents. Here we define "similar
cache lines" as cache lines where most bytes on the same offset are identical, but a few bytes can differ from each other.
This paper does not exploit value locality of bytes that differ, but rather just store diff bytes uncompressed. 
From a high level, Thesaurus computes a "fingerprint hashing" value as the identity of the cache line. The fingerprint
hashing function is content-aware, meaning that it has the property that if two cache lines are similar to each other, 
then there is a higher chance that their fingerprint hashes will be identical. On the other hand, if two lines differ
from each other by a large amount, then there is only slim chance that their hashes would coincide.

Thesaurus computes the fingerprinting hash as follows. The cache line content is treated as a 64-element column vector.
Given a fingerprint length of K, the transformation matrix is defined as a K * 64 matrix with elements randomly selected
from {-1, 0, 1} with zero having probablity of 2/3 and the other two having a probablity of 1/6. After multiplying the 
transformation matrix with the 64 * 1 vector, the resulting K * 1 column vector is then mapped to a simpler form by 
quantifying all positive elements to 1, negative elements to 0, with zero elements remaining the same. The final result
can be represented as a bit vector which can be compared with each other by hardware rather efficiently. 
The intuition of the transformation is that if two cache lines are similar to each other, then it is likely that the linear
combination of elements using 1, 0 and -1 also yields results with the same sign. Using several different linear combinations
is just to control the probability that the above property holds. 
Note that if two cache lines are identical, then their fingerprint will also be identical, making Thesaurus a superset
of conventional cache deduplication.

We next describe the cache organization as follows. Thesaurus adopts a decoupled tag and data array design as in 
[V-Way cache](%post_url 2020-05-27-vway-cache%) and its predecessor, [2DCC](%post_url 2020-07-22-2dcc%). The tag
array is over-provisioned to increase the maximum effective size of the cache, and still accessed as in a conventional
cache, being indexed with lower bits of the block address. Replacement algorithm is run unmodified as in a conventional
cache as well. The added tags can either be implemented as additional ways at the cost of parallel tags reads on each
lookup, or as extra sets, which uses one or more bits in the block address to generate the index.
Each tag array contains a global data array pointer and a segment ID field to point to the physical slot and the 
segment in which the compressed block is stored. Tag and data accesses are thus serialized since the tag must be read
first before the location of data ia available.
In addition, a format field is added to the tag entry to indicate the compression type of the entry. As we will
discuss later, Thesaurus supports four different compression types.
The fingerprint value is stored in the tag entry, if the compression type is base or base + delta.

The data array, on the other hand, is a fully associative array, meaning any slot can be addressed by any tag entry.
A bit vector is maintained for allocation of free data slots. 
The data array is also segmented such that partial slot can be used to store a compressed line, with multiple compressed
lines residing in the same physical slot.
Eviction on the data array is more complicated since potentially the all entries in the data array can serve as the candidate. 
To simplify candidate selection, the paper suggests that the same replacement algorithm in 2DCC be used: Data slots are 
divided into sets as in a conventional cache only for the convenience of eviction. The algorithm, after failing to allocate 
a free block for a fill or write back request, randomly selects four sets and checks free segments for all slots in these 
sets. The one with sufficient number of free segments will be selected. If this is impossible, then segments from one of the 
slots will be evicted until enough number of segments are freed. 
Note that no tag back pointer exists per-segment as in 2DCC. This is because if most blocks use more than one segments,
having a per-segment back pointer would be a waste of storage. To this end, the tag back pointer is always prepended
at the beginning of a compressed or uncompressed block. On eviction, the tag entry can be located by reading the first
few bits of the header segment.

Thesaurus adopts an aggressive slot compaction strategy to simplify storage management. Compaction is always performed 
on an eviction and insertion. When a block is evicted, all following blocks will be moved forward to fill the gap left 
by the eviction. 
One particular difficulty of moving blocks around in the physical slot is that the corresponding tag entries must be 
modified accordingly to point to the correct segment as blocks are moved. To avoid this costly operation for each
compaction operation, the paper proposes that an extra level of indirection, called the start map, be added to each 
physical slot. The start map is a bit vector whose length equals the number of segments in the data slot. A "1" bit indicates
that the segment has been occupied, while a "0" bit indicates that it is free. Tags use the offset in the start map
to refer to blocks. The actual segment offset of a block is computed by counting the number of "1"s before the tag 
pointer's indicated location in the start map. When a block is freed, instead of changing its tag pointer, the controller 
simply sets all segments it uses to "0", and performs compaction. The blocks that are moved during the compaction will 
be accessed correctly, since the zero bits in the start map will result in these blocks' segments being moved forward as 
well.
When a new block is to be inserted, the controller first attempts to find a run of zeros which the block can fit into.
If this can be found, then these bits will be set to "1" to indicate that the segments are being used. In the meantime, 
all blocks after the range is shifted towards the end by the number of bits that are changed to "1".
Otherwise the replacement algorithm is invoked to find eviction candidates as described above.

Thesaurus maintains a fingerprint table in the main memory to perform clustering. A TLB-like structure, called the base
line cache, is added to the hierarchy as a fast supplement of base lines. When a new line is filled or written back,
the cache controller first computes the fingerpring of the line, and searches the base cache for a matching value. If
a match is found, then the byte-level delta between the incoming line and the base is calculated, and stored as the body 
of the compressed block. A 64-bit vector is also attached to the body, with each bit indicating the presence of a delta
value. As a special optmization, if the two lines are an exact match, no body of the line will be stored. Instead, the
controller will simply allocate a tag, and point the tag to the base block.
If a match cannot be found, then the main memory base line table is searched using the fingreprint as the key.
If there is still no matching, then an element in the main memory table is evicted, which is then replaced by the newly
inserted line content and fingerpring. The base line is also inserted into the base line table, and a tag entry pointing 
to the new base line is allocated by storing the fingerprint value in the tag.
If an entry is found, then it will be loaded into the base line cache, before the lookup is re-attempted.

Although the paper does not mention the specific data layout and management of the main memory base line table,
it is suggested that each base line also has a reference count, which is incremented when a new tag entry points to the 
base line or when it is used as the base line, and decrememted when an entry pointing to the line is evicted. When the 
reference count drops to zero, the base line entry is invalidated.

In the above discussion, we have covereds two of the four compression modes: If the block is not present in the base line
table, then it is stored in the table, and the compression type is set as "base", indicating that the entry is to be 
fetched from the base line table with no extra delta.
If, however, the line has a small delta compares witn the base line, then the compression type is "base + delta", indicating
that the controller should access both the data array for delta, and the base line cache for the base at the same time, 
before combining them together to restore the original line.
If the line has a large delta, which exceeds the uncompressed line size, the line will be stored in raw format, with the
compression type set to "raw". Note that this should be extremely rare, since the probablity that the delta is small when
two fingerprints match is high.
At last, if the incoming line consists of all-zeros, then it will be marked as "zero" in the compression type field,
and no data body is allocated from the data slot. 