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
If a cache hit is signaled, the hit must either be in the baseline cache, or in the victim cache, due to exclusiveness.
If the hit occurs in the baseline cache, no special operation takes place, and the hit is processed the same manner as in
a regular cache (e.g. updating LRU stack). 
If, however, the hit occurs in the victim cache, the block is swapped with an evicted line from the baseline cache.
This is equivalent to fetching a new line from the lower level on a baseline cache miss, if the victim cache were not 
present. Our optimization reduces the latency of such misses.
The baseline cache initiates a fill just like a regular cache would do on a cache miss. The replacement algorithm is also
invoked to find a victim. Once the victim is found, it is evicted from the baseline, and opportunistically inserted into 
the victim cache. The victim block that gets hit, on the other hand, is inserted into the baseline cache. We next describe
how these two operations are achieved in the proposal.

A block evicted from the baseline cache is always opportunistically inserted into the victim cache, not necessarily on the
same way as it was in the baseline. 
The cache controller attempts to find a slot in the victim cache that could hold the victim block. Recall that the victim
cache shares the same physical slots with the baseline cache, the cache controller simply scans the tag slot array
and finds a way in the current set whose upper half is larger than the compressed victim size. In the case of multiple
candidates being found in the victim cache, the replacement algorithm is invoked to evict one of them to the lower level,
after which the evicted block is inserted. 
Similarly, when a block from the victim cache is to be inserted into the baseline cache on a victim cache hit, the 
baseline replacement algorithm is invoked, and one line is evicted from the baseline to make space for the line fill.
Note that the block to be brought into the baseline cache may not fit into the physical slot, if the upper half of the 
slot contains a victim cache block that prevents both from fitting into the physical slot. In this case, the victim block
on the upper half is evicted, as we always prioritize baseline cache blocks over victim blocks. 
In total, in order to perform a block swap between the victim cache and the baseline cache, at most two write backs are
generated to the lower level, with one always being one of the victim blocks (during baseline cache insertion), and the 
other being either victim block or the baseline block (during victim cache insertion). The number of blocks evicted 
can also be zero (perfect swap) or one (always happen during victim cache insertion).

If the request misses in both caches, then a regular line fill is initiated to the lower level, and the block fetched
from the lower level is directly inserted into the baseline cache, to ensure that the baseline cache always behave the 
same way as a regular cache as if the victim cache were not present.

When a block is moved from the baseline cache to the victim cache, it is up to the protocol designer whether the 
block should abandon ownership if it is in dirty state (M state). 
If the protocol indicates that ownership should be abandoned, then when such block swap happens, the cache controller
should also revoke the exclusive permission of the block from upper level caches if the hierarchy is inclusive.
In this case, it appears to the coherence protocol as if the block were already evicted from the LLC.
Write requests from upper levels can never hit the victim cache, if the LLC is inclusive, since ownership of this block 
must have already been dropped and transferred to the lower level, implying that no upper level cache should have
ownership (and therefore a dirty copy) either. 