---
layout: paper-summary
title:  "Scavenger: A New Last-Level Cache Architecture with Global Block Priority"
date:   2020-05-28 22:34:00 -0500
categories: paper
paper_title: "Scavenger: A New Last-Level Cache Architecture with Global Block Priority"
paper_link: https://ieeexplore.ieee.org/document/4408273/
paper_keyword: Scavenger; Priority Queue; Heap
paper_year: MICRO 2007
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Scavenger, a last-level cache (LLC) design that features a regular cache and a priority heap as victim
cache. The paper points out at the beginning that as cache sizes increase, doubling the size of a cache can only bring 
marginal benefit by reducing the miss rate. In the forseenable future where more transistors can be integrated within the
same area and power budget, existing cache architectures may not scale well.

The paper makes one critical observation that most LLC cache misses (it was actually L2 at the time of writing) are on
addresses that have been repeatedly accessed in the past, i.e. some addresses are referenced by the upper level on a regular
basis, while they are not accessed frequently enough to avoid being evicted by the upper level replacement algorithm 
before the next reference. One simple solution would be to add a small victim cache on the LLC level, which holds 
evicted lines from the LLC for an extra period of time before they are truly written back to the memory. This, however, 
does not help in our case, since the observation also points out that the interval between two repeated references is 
far more larger than any of the reasonable implementations of a fully-associative victim cache.

Scavenger enhances the classical monolithic LLC cache organization as follows. Given a storage budget (e.g. number of 
bytes the total storage could be), Scavanger divides them into two separate parts. The first part is a conventional
set-associative cache of half of the storage budget. The second part is organized as a fully-associative priority heap 
using the rest half of the storage budget. The hardware also tracks the access frequency of addresses that miss the 
conventional part of the LLC using a bloom filter. When a line is evicted from the conventional part, its access frequency 
is estimated using the bloom filter. If the frequency is higher than the lowest frequency line currently in the priority
queue, the lowest frequency line in the queue will be evicted back to the main memory, and the evicted line is inserted.
In addition, on an access request from the upper level, both parts are probed for the requested addess. These two parts
maintain exclusive sets of addresses. If the priority queue is hit by the request, the block being hit will be migrated
back to the conventional part of the LLC.
