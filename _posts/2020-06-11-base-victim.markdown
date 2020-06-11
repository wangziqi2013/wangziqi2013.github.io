---
layout: paper-summary
title:  "Base-Victim Compression: A Opportunistic Cache Compression Architecture"
date:   2020-06-11 01:17:00 -0500
categories: paper
paper_title: "Base-Victim Compression: A Opportunistic Cache Compression Architecture"
paper_link: https://dl.acm.org/doi/10.1145/3007787.3001171
paper_keyword: Compression; Cache Tags; Base-Victim
paper_year: ISCA 2016
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Base-Victim LLC compression architecture, which improves over previous tag mapping scheme designed
for compressed caches. Conventional tag mapping schemes suffer from several problems, as pointed out by the paper.
First, to accommodate more cache lines in a fixed number of ways, compressed caches often over-provision tag arrays
in each set, and allows fully associative mapping between tags and data slots. In addition, since compressed blocks 
have smaller size than a full physical slot, the physical slot is divided into multiple segments, allowing tags to
address to the middle of a slot using segment offset. Such fine grained tag mapping scheme creates two difficulties.
The first difficulty is internal fragmentation, which happens when two compressed lines could have fit into the same
physical slot, but the actual data layout in the slot requires extra compaction, moving segments around, which takes
more complicated logic and more energy. The second difficulty is that tag reading logic changes much by adding the one
more level of indirection. More physical slots are activated during the read process, which is against the energy saving
goal on commercial products.

The second problem of previous tag mapping schemes is that eviction algorithms no longer work the same, as more 
cache lines than the number of ways can be stored in a set. In addition, since cache lines are no longer of uniform
sizes, the eviction algorithm may have to write back more than one dirty blocks to the lower level before sufficient
number of bytes is available for the line fetch. Even worse, if tags and data slots are not fully associative, eviction
candidates within a cache is even more restricted, which can degrade performance, since the well-tuned replacement
algorithm no longer behaves in the same way as in an uncompressed cache.

This paper makes a trade-off between the flexibility of tag mapping schemes and the simplicity of implementation. 
Tags are still over-provisioned per set by doubling the number of tags in a standard set-associative cache, allowing 
a maximum compression ratio of 2:1. Tags and data blocks are still statically bound, allowing no fully associative tag 
mapping as in some other designs. Compressed blocks can be placed in one of the two tags, which map to the upper half
and lower half of the data slot respectively. Since a compressed block can either reside in the upper half or the lower 
half, internal fragmentation is impossible, as long as the upper half is always aligned to the end of the data slot by 
the last byte (i.e. the last byte of the upper half compressed line is always the last byte of the physical slot).

Instead of treating every tag in the tag array equally as first-class citizen, this paper proposes dividing the tag array,
and henceforth the logical cache storage, into two equally sized parts, called the baseline cache and the victim cache. 
Recall that each way has two tags statically mapped to the way's physical slot. It is also statically designated that 
one of the two tags belong to the baseline cache, and the other belongs to the victim cache.
The tag mapping and replacement protocol ensures that the baseline parts operate exactly the same as a regular set-associative
cache, suggesting that the hit ratio of the compressed cache would be at least the performance of the regular cache,
drawing a lower bound for the compressed cache design.
Better performance could be achieved as a result of compression and the resulting larger effective cache size.
Both parts of the compressed cache also run different instances of replacement protocols.
In the paper, the baseline cache runs conventional LRU, while the victim cache runs random eviction.

One of the most important invariant is that the content of the baseline cache would always equal to a regular cache 
of the same organization running the same replacement algorithm. 
The baseline and victim cache operate individually as two independent caches, with the victim cache holding victim
blocks evicted by the baseline cache. Exclusiveness is maintained between these two caches, such that one address
can only exist in at most one of the two caches.
The difference between a victim cache design with a victim cache of the same organization as the baseline cache is 
that, in the paper's proposal, the victim cache "borrows" storage from the statically mapped physical slot of the 
baseline cache. Space borrowing is made possible by the usage of compression, since data blocks in the baseline cache
take less space, enabling the victim tag on the same location to map an extra victim block to the rest of the physical
slot. We next describe the operation of these two caches.

On an access request, all tags in the selected set are read out and checked against the requested address. This is equivalent
to checking both the baseline cache and the victim cache on an access. 
If a cache hit is signaled, the hit must either be in the baseline cache, or in the victim cache.
If the hit occurs in the baseline cache, no special operation takes place, and the hit is processed the same manner as in
a regular cache (e.g. updating LRU stack). 
If, however, the hit occurs in the victim cache,
