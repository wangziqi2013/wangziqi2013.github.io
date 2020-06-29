---
layout: paper-summary
title:  "Column Associative Caches: A Technique for Reducing the Miss Rate of Direct-Mapped Caches"
date:   2020-05-30 06:34:00 -0500
categories: paper
paper_title: "Column Associative Caches: A Technique for Reducing the Miss Rate of Direct-Mapped Caches"
paper_link: https://ieeexplore.ieee.org/document/698559
paper_keyword: Cache; Column Associative
paper_year: ISCA 1993
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Software concept of multi-probing hash table can be directly applied to direct-mapped caches, treating the 
   direct mapped tag array as the data array of a hash table.
2. It is common practice to swap the more recently accessed element to the head of the hash chain, as in robin hash

This paper proposes column associative cache, a simple enhancement over direct-mapped cache design for better hit
rate and performance. The paper observes that, at the time of writing, direct-mapped caches are majorly used as 
first level caches which require low hit latency and fast access. More complicated set-associative caches often could
achieve a better hit rate, but accessing a set-associative cache set would require the controller to read out several
tags and data slots in parallel, which incurs larger latency, due to the decoding and accessing logic of a large array.

Direct-mapped caches, on the other hand, suffers from lower hit rate than a set-associative cache, since each address
can only be mapped to one slot, instead of many. Prior proposals such as victim cache can flexibly add extra ways to
certain sets using a small, fully-associative buffer to hold evicted lines from the L1. It, however, adds undesirable
overhead, such as extra decoding and fully-associative accessing logic, and extra data slots to store cache line data. 

The goal of this paper is to achieve the efficiency of a two-way set-associative cache, without the overhead 
of extra decoding logic and data slots. The latency of the resulting design should also be as low as a direct-mapped
cache.

The proposed design works as follows. Instead of only storing a cache line in one location, the cache controller has
two hash functions, one using the conventional mapping, i.e. taking lower bits from the line address, and use it 
as the index for the set, and the other just flips the highest bit of the aforementioned index to form a new index. 
In this paper the first index is called b(x) and the second is called f(x), where x is the requested address.
The reasons for flipping the highest bit are that: (1) This simplifies tag management, since only one more bit
at the flipped location is needed to be stored as the tag; (2) These two addresses are expected not to be accessed
together, since they are far away from each other in all cases regardless of the tag part, which is consistent with
locality of computation. 

On an cache access request, slot at index b(x) is first tested. If tags match, the line is returned as in a normal
cache miss. Otherwise, if there is a miss, the slot at f(x) is also tested. If the test indicates a hit, then a 
second hit is signaled, and the data item at f(x) is swapped with the one at b(x). 
If the second probe still results in a miss, then a cache miss is signaled, and a request is made to the next level.
After the request is fulfilled by the next level, the newly fetched line is installed into the secondary location,
and the two locations are swapped.
The swap operation ensures that more recently accessed data will always be put on the first-hit location, which reduces 
the chance that a second probe is needed, helping reducing the hit latency.
Evictions are also needed, if the second probe misses, and the secondary location already contains a valid line.

**Note: Although this paper adopts a different way of comprehending the operations, this is essentially the same 
as a design in which evicted lines are unconditionally kicked to the secondary location after evicting the cache 
line on that location.**

Note that in order to correctly test tags for address match, the highest index bit should be stored as the tag, 
as in a two-way set-associative cache design of the same size (the number of ways is reduced by half, so one less bit
is used to generate the index). Otherwise, two addresses only differing by the flipped bit will singal false positives
for each other.

The hash-rehash design discussed above may suffer from miserable thrashing, if two addresses, A and B, are alternatively 
requested, and b(A) = f(B) (which also implies that b(B) = f(A)). In this pessimistic case, an access to A will incur a 
secondary slot miss, which evicts B, fetches A, and swaps A to its primary location. Then an access to B incurs a secondary
miss as well, which evicts A from its primary location, fetchs B, and swaps B to its primary location. Such thrashing behavior
is not expected in an optimal design, since both can just co-exist within the same virtual set, i.e. A being stored at
location b(A) while B being stored at location b(B). 

The root cause of the prssimistic case is the fact that simple hash-rehash design is biased towards the secondary location.
If an address misses its primary location, then either it hits the secondary location, or it evicts the line from the 
secondary location. If the secondary location also happens to be a more frequently accessed line than the one on
the primary location, then such eviction decision is sub-optimal.

To solve this issue, the paper also proposes adding a "rehash" bit to each slot. The "rehash" bit is set, when the slot
stores a line as its secondary location. The access protocol is also slightly modified as follows. When the first probe
at the primary location fails, the cache controller tests the rehash bit before testing the secondary location. If the 
rehash bit is set to 1, then the line at the primary location is evicted before the new line is fetched, and no swap
happens. When a cache line is migrated to its secondary location, the "rehash" bit it set, and when a line with this bit 
is evicted due to a miss, the bit is cleared (this must be the case that another address takes its primary location).
This makes sense, since we swap lines on every secondary hit, such that the more recently accessed line is always stored 
on the primary location. If the "rehash" bit is on, indicating that the current slot stores a less frequently accessed line
evicted from its primary location, then we evict this line, instead of the line on the primary location.
A better way to call the "rehash" bit is actually "less used" bit, to emphasize that fact that the slot is secondary choice
for the address currently stored in it, and the cache controller should priority evicting this line rather than the 
address in the primary slot, which can just be swapped there because of a cache hit. 
At system startup, all "rehash" bits are set to prioritize evicting the location on first probe. 
On invalidation of any kind (forced invalidation, coherence invalidation), the bit is unchanged. Note that one may
feel tempted to set the rehash bit on invalidation. This will break the design, since some accesses may incur 
false cache miss. To see why this happens, imagine the case where addresses A and B both map to the same 
primary and secondary locations. Both A and B are accessed (in this order). Now the primary location contains 
address B while the secondary address contains A. If now an external invalidation sets the "rehash" bit on the primary
slot, then any future access to address A will never hit the secondary location, and two copies of address A exist.

The paper also disproves the possibility that an address A be stored in its secondary location y, while the primary location
x has its rehash bit set. In order for this to happen, either A is stored to y before the rehash bit on x is set, or 
vice versa. In the first case, another address B must have probed y and x (in this order), resulting in misses, fetched
a line, and swapped with it. In this case, the actual address stored in y must be B, not A. In the second case, the bit is 
already set when A is stored to y. This, however, is only achievable when the access first probes x since x is the primary
location. After x is probed, A will be stored in x without probing y, since the rehash bit is set, and priority
is given to address A.
