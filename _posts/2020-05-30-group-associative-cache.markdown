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
whether the access results in hit or miss. 
