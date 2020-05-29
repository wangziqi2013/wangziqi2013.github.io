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

As discussed above, the access frequency estimator is implemented as a counting bloom filter. An incoming address is divided 
into three segments (this paper assumes 32 bit address). The paper observes that the upper bits of the address are often
not changing much from access to access, while the lower bits change significantly. The implementation, therefore, divides 
an address into low 15 bits, middle 8 bits, and high 3 bits (note that the address is block aligned, with the lowest bits
being zero), and each segment addresses one counter in each of the three individual counting bloom filters.
To further increase accuracy, bit 9 - 18 and bit 19 - 24 are also used to form two extra segments, which address 
another two counting bloom filters. 
All counters addressed by these segments are incremented by one if the access misses the conventional LLC.
When an estimation is to be made, the address to be estimated is divided in the same manner as described above.
Then each of the counters are read in parallel, and the minimum is selected as the estimated access frequency. 
Selecting the minimum value from multiple bloom filters help reducing address aliasing, which is a common issue with 
bloom filters. 
The paper also suggests that these bloom filters can be implemented as individual RAM banks, each with a built-in 
incrementing logic and a read port.

The priority queue part of the LLC consists of a min-heap and a victim cache. The min-heap maintains frequency information 
for blocks stored in the victim cache. Each entry in the min-heap has an integer field representing the frequency, and 
a pointer to the victim cache for whom the frequency is maintained. 
The victim cache is organized as a hash table with chaining for conflict resolution. 
These two components work together to reduce the number of cache misses in LLC, as we will see below.
