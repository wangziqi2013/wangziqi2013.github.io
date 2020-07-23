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
