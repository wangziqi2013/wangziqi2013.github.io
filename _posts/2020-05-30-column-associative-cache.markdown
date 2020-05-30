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
On an cache access request, slot at index b(x) is first tested. If tags match, the line is returned as in a normal
cache miss. Otherwise, if there is a miss, the slot at f(x) is also tested. If the test indicates a hit, then a 
hit is signaled, and the data item at f(x) is swapped with the one at b(x).


