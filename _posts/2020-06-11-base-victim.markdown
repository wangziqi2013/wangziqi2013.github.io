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

This paper proposes Base-Victim cache compression architecture, which improves over previous tag mapping scheme designed
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