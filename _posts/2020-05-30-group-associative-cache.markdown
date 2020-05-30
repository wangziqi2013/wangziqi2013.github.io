---
layout: paper-summary
title:  "Capturing Dynamic Memory Reference Bahavior with Adpative Cache Topology"
date:   2020-05-30 11:00:00 -0500
categories: paper
paper_title: "Capturing Dynamic Memory Reference Bahavior with Adpative Cache Topology"
paper_link: https://dl.acm.org/doi/10.1145/291006.291053
paper_keyword: Cache; Group Associative
paper_year: ASPLOS 1998
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes group-associative cache, a direct-mapped cache design that dynamically adjusts association relationships 
between sets. The paper observes that cache accesses are often skewed in a way that many accesses actually happen to a
limited subset of all sets in the cache. This inevitably divides the cache storage into frequently accessed lines and 
infrequently accessed lines, or "holes". The existence of holes negatively impacts cache performance, since they could 
have been evicted by a global ereplacement policy, and reused for hosting those frequently accessed lines.

Existing set-associative designs allow a line to be stored in multiple possible locations, called "ways", to achieve lower
miss rate then direct-mapped caches. This, however, does not fully solve the proble, since replacement decisions are also
made within a set, without global replacement. Prior works such as victim caches and column-associative caches also do
not work well. Victim cache attempts to solve the problem by adding extra decoding logic and data slots, which can be 
practically difficult or even impossible at the time of writing this paper. Column-associative caches only allow one 
address to be remapped to a statically fixed location, without actually tracking line usage frequency, which can itself
be a problem, since frequently used lines may just evict each other.

Group-associative caches, on the other hand, differs from previous works in three aspects. First, it explicitly tracks 
recently accessed sets in a buffer structure, called the Set-reference History Table (SHT). This allows the hareware 
to identify potentially frequently accessed sets, and protect them from future write requests by remapping these writes
to a different set. The second aspect is that group-associative cache remaps addresses in a fully-associative manner,
i.e. an address that is supposed to be mapped to a protected set can be remapped to any set in the cache, as long as 
the set is not protected. This enables a broader range of mapping relation than, for example, statically fixing the mapping 
by only flipping the highest bit in the set index. A dedicated structure, called Out-of-position Direction, or OUT,
tracks these remapped addresses and the sets they are mapped to. The last aspect is that group-associative cache classifies
slots into disposable or non-disposable. A disposable line can be evicted for displacements of non-disposable lines, while
non-disposable lines should not be evicted unless they are evicted by OUT or SHT.

We now introduce details of operations as follows. The SHT is maintained as a fully-associative buffer consisting of 
set indices that have been recently accessed. This table is updated every time an access takes place, no matter
whether the access results in hit or miss. Each set also has a per-set disposable bit (the "d" bit), the semantics 
of which will be explained below. If a set is entered into the SHT by an access, the "d" bit of that set will also be 
cleared to indicate that the set may be referenced again shortly. 

The OUT table is maintained as an associative buffer mapping addresses to slot indices. the structure of OUT is not 
specified. It is, however, later implied in the paper that OUT can be a set-associative search structure, 
with a replacement policy just like a set-associative cache. 
Addresses can be inserted and evicted from OUT as well. Addresses mapped by OUT will override the tag field in the slot, 
i.e. if the OUT maps address A to slot x, then the tag field of slot x is ignored during a cache lookup.
Sets mapped by OUT also have their "d" bit cleared. The "d" bit is only set once the address is evicted from the OUT
table, and the set index is not in SHT. Note that the paper also suggests that SHT and OUT must be exclusive. A slot
mapped by OUT must not be in the SHT, although the reason is not given.

The size of OUT and SHT should be carefully tuned in advance to avoid hurting performance. If these two structures are 
too small, not sufficient number of cache lines and slots can be stored, and the effect is not easily observable.
On the other hand, if these two structures are too large, then even non-frequently used cache lines will also be 
aggressively identifyed and remapped, which again negatively impacts performance, since the cache still stores less
frequently used data. 

On a cache access, the SHT is updated regardless of whether the access hits or not, unless it hits the OUT.
The cache controller probes OUT and the direct-mapped tag array in parallel. If the tag array indicates a hit, then
the data is directly returned. Otherwise, if OUT is hit, then the index of the slot is read out, and the data array
is accessed in the next cycle. After an OUT hit, the line is also swapped with the line in the primary location,
since the OUT mapped line is expected to be accessed later, and swapping it to the primary location reduces
hit latency (i.e. tag check and data read can be performed on the same cycle).

If neither OUT nor tag array signals a hit, the miss is handled based on whether the "d" bit is set on the primary location.
If set, then the line is not identified as a frequently accessed line, and can be directly evicted. Otherwise, the line 
should be "pinned" in the cache as long as possible, and the cache controller will find a disposable victim elsewhere.
If the OUT table has empty entries, then the empty entry will be taken, and the cache controller scans the tag array
and finds a disposable line with "d" bit on. The line will then be evicted, after which the entry mapping the requested 
address to the line is added to OUT.

If there is no empty entry in OUT, then an eviction decision should be made, and one entry is evicted out of OUT.
The paper suggests that LRU be used for the set-associative OUT. When the entry is evicted, the "d" bit of the 
corresponding slot is also set, since the line has been in OUT for a while, but never accessed according to LRU.
Then the data of the slot is evicted, after which the incoming data is written.

The paper also proposes integrating cache line prefetcing with group-associative caches. When prefetched lines arrive
at the cache, the "d" bit of the slot is tested. If "d" bit is on, then the line is evicted, since it is not expected
to be accessed later, and the prefetched line takes the slot. If the "d" bit is cleared, then the prefetched line is 
inserted into the cache similar to how a miss is handled.