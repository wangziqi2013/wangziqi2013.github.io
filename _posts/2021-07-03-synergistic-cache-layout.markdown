---
layout: paper-summary
title:  "Synergistic Cache Layout for Reuse and Compression"
date:   2021-07-03 06:32:00 -0500
categories: paper
paper_title: "Synergistic Cache Layout for Reuse and Compression"
paper_link: https://dl.acm.org/doi/10.1145/3243176.3243178
paper_keyword: YACC; Reuse Cache; FITFUB; First Use
paper_year: PACT 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Use a special state, "first-use" state, to indicate that a block has been accessed for the first time. The state
   can be represented using one bit, which will be cleared on the second access before eviction;

2. First-use blocks are not cached by the LLC, since they often have low locality. They are only cached on second use
   and so on. This rule can be implemented with just the first-use bit: When a block hits the LLC but the bit is set,
   the block will be inserted. Otherwise, the missing block will not be inserted.

3. In a compressed cache, the number of tags are more than the number of data slots. This naturally fits into 
   this first-use model, as it requires more tags than data slots in order to track blocks whose data is not 
   cached (this is the way a compressed cache works).



This paper proposes a cache insertion policy that increases actual block reuse by delaying the insertion of the data
block. The paper is motivated by the fact that, at LLC level, block re-usage is not as common as one may expect at 
higher levels of the hierarchy, mainly because locality has already been filtered out by higher level caches.
Traditional replacement algorithms such as LRU assume that blocks will be re-referenced shortly after being inserted,
and hence gives it low priority for replacement. In addition, the cache always defaults to an always-allocate policy,
i.e., a cache block is always inserted into the cache when it misses the LLC, assuming that the block will be 
referenced again in the future. 
Both assumptions are not true, and they work particularly bad for certain benchmarks such as libquantum, where 
streaming (scans) is the dominant access pattern.

Reuse cache, a prior proposal, attempts to address this issue by over-provisioning the logical tag associativity
by 4x, and tracking blocks that are first-time referenced since the last eviction in those over-provisioned 
tags. A block is only inserted into the data array (and evicts an existing block) when the block is referenced for
the second time. 
Although the design successfully increases overall performance by reducing unnecessary insertions that will never
be re-referenced, the paper noted that it also incurs a huge metadata overhead on the cache, which makes it infeasible.

Instead of adding extra tags, the paper observes that extra tags can be obtained "for free" from a super-block based 
cache, which can also be potentially compressed. 
In a super-block based cache, each tag encodes four (or even more) consecutive blocks in the address space, 
4i, 4i + 1, 4i + 2, and 4i + 3. Each block has its own state bits, and they react independently to coherence events.
Multiple tags can co-exist in the same set, as long as they encode disjoint set of blocks.
The paper also assumes a static, one-to-one tag-data mapping, i.e., no matter whether the cache is compressed, 
blocks encoded by a tag can only be stored in the data slot bound to the tag.
In the compressed configuration, blocks are first compressed before being inserted, and decompressed before
being written back and sent to upper levels. Depending on the compression ratio, one data slot can store up to
four compressed blocks, which equals the number of blocks per super-block.

The design implements the high-level idea that, when a block is first-time inserted into the cache since the 
previous eviction, instead of inserting data into the set, which may potentially evict another block of higher
locality, the cache always assumes that the block is of low locality, and bypasses the LLC. The actual block is
only inserted into the cache when the block is accessed for the second time, which indicates that the block may
potentially be accessed later, and caching the block will bring actual benefit. 

This high-level idea can be implemented by adding an extra bit per logical block in the super-block cache.
If the bit is set, the logical block is considered to be a "first-use" block, which is assumed to have low locality.
Data of a first-use block will not be cached, and the response message (with data) is directly sent to the upper level.
The first-use block is not inserted into the replacement chain (e.g., LRU stack), as the block cannot be evicted
to free storage (it can still be evicted when the entire tag is evicted).
Note that the directory still maintains the coherence state and the sharer vector of the first-use block, although
the block can only be in shared or exclusive state (S or E in MESI) as a first-use block, as being dirty makes no sense
for the block.
Note that the block can still be dirty in upper level caches, which is also tracked by the
coherence controller, but it is different from the LLC's coherence state which is tracked by the LLC's tag array.

We first discuss the operation on uncompressed caches.
When a request hits a first-use block, there are two cases. 
The first case happens if the block is in dirty state in the coherence controller, indicating that a peer cache of 
the requesting cache must have already written to the block and hence have the most up-to-date data.
In this case, the LLC acts as a normal coherence controller, which forwards the request to the current owner of the 
block, and downgrades the block to shared state. Note that in this process, the block will also be written back 
to the LLC as part of the ownership transfer process. The LLC will not be bypassed, since it is the second time 
the block is referenced, which implies that the block should actually be cached. 
The LLC will therefore allocate an entry for the block being written back, by evicting another block, and add the
block into the replacement chain.

In the second case, there is no most up-to-date block being cached at the higher level. The LLC will be hit, since 
the first-use tag is already present. Since no data is actually being cached, the LLC will forward the request to 
the lower level, fetching the block, and insert it into the data slot.
In both cases, the first-use bit is also cleared.

When a dirty block is written back from the upper level as a result of eviction (rather than coherence write back),
the LLC will check whether the first-use bit is set. If true, the block will bypass the LLC, and by directly written
back to the main memory. The tag in the LLC need not be evicted as it can still track the status of the 
first-use block. Otherwise, normal write back logic is performed, which can still bypass the LLC, if the LLC is
not inclusive.

If the cache is compressed, then whether the cache is bypassed is opportunistic: If the block to be inserted is 
compressible, and it could fit into the slot after compression, then the block will always be inserted, since this
operation will not incur any eviction, and the first-use bit will not be set.
Otherwise, if the block is not compressible, or the insertion of a compressed block will incur an eviction, the 
first-use bit is set as in the uncompressed case.
Write backs are handled in the same manner as in the uncompressed case.

The paper also noted that, in the case where multiple tags on the same super-block exist in the same set,
the insertion of a first-use block should set the flag in all the tags, such that the first-use information can be
tracked as long as the super-block is cached. 
Similarly, the bit is cleared in all tags when the block is accessed for a second time.
Since these super-block tags are in the same set, both operations only need one parallel tag access.
