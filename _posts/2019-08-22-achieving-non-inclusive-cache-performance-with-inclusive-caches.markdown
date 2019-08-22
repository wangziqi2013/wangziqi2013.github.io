---
layout: paper-summary
title:  "Achieving Non-Inclusive Cache Performance with Inclusive Caches"
date:   2019-08-22 01:39:00 -0500
categories: paper
paper_title: "Achieving Non-Inclusive Cache Performance with Inclusive Caches"
paper_link: https://ieeexplore.ieee.org/document/5695533
paper_keyword: Inclusive Cache; Non-Inclusive Cache; Temporal Locality
paper_year: MICRO 2010
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Non-inclusive and exclusive caches are often used as a replacement for the classical inclusive cache in the cache hierarchy,
aiming for better performance. The classical inclusive cache hierarchy mandates that all cache blocks in upper level caches
must be present also in the shared cache. The last level cache hence stores a super set of blocks that are in the private caches.
On a coherence request, if an address cannot be found in the shared cache, then the request will not be forwarded to higher 
level caches, since the shared cache essentially acts as a coherence filter. 

This paper identifies two problems with inclusive caches. The first problem is that when the number of cores reach a certain
level, for example, when the sum of private cache sizes are larger than one-eighth of the shared cache, performance will begin to
deteriorate compared with other caching policies. This problem can be solved by not requiring the shared cache to keep all
blocks in private caches, hence freeing more space for data currently not in the cores' working set. The second problem
is that the access pattern to the shared cache is very different from the pattern to core cache. To be specific, core cache
accesses often have temporal locality which suggests that an address accessed in the past is likely to be re-accessed in the 
near future. For shared caches, especially last-level caches, however, this is not true, since the temporal locality has
been filtered out by upper level caches. A frequently accessed block in the core cache will remain unaccessed for a long 
time in lower level caches, which will gradually move to the LRU position, and finally be evicted. The eviction of the 
block in the shared cache, however, will inevitably result in the eviction of the block from core caches also, since 
inclusiveness (and hence correct coherence) must be maintained. The paper points out that this phenomenon is particularly
harmful, when an application whose working set fits into L1 is running in the system with another application whose working 
set is equal to or larger than the shared cache. In this case, due to frequent misses in the core cache of the second 
application, cache blocks brought into the shared cache by the first application is likely to be invalidated shortly even 
if the block is frequently accessed by the first application.

Two alternatives are present which do not require the maintenance of inclusiveness. In the first solution, non-inclusive
caches, cache blocks are not evicted from the core cache even if they are evicted from the shared cache. This preserves 
locality in the core cache, at the cost of extra coherence traffic forwarded from the shared cache, since now the 
shared cache is unsure whether a block exists in the private cache or not even if the address does not exist in the
shared cache. The other option is exclusive cache, which explicitly disallows inclusion. Exclusive caches have the 
extra bonus of larger effective capacity, since all cache storage can be used to store non-duplicate blocks. It is, however, 
more bandwidth-hungry, because now every eviction from the upper level has to be written back into the lower level,
since the lower level does not have the block. By contrary, inclusive and non-inclusive caches can simply discard a clean
block when it is to be evicted, since the lower level cache definitely (or is likely to) contain the evicted block.
In practice, exclusive caches are designed such that when the core cache misses, the fetched block is directly transferred
to the core cache instead of inserting it into every level. Similarly, if a line is hit in a non-core cache (which 
implies that an upper level cache misses), the line is invalidated before it is sent upwards.

The paper identifies the root cause of the problem being that the core cache being unable to communicate locality to
lower level caches. As long as the lower level cache has a way of knowing a block is frequently accessed by the core
cache, the block to be evicted can be preserved instead, and no back invalidation is needed. 

The first scheme, called Temporal Locality Hints (TLH), uses a straightforward method of sending every L1 hit to 
lower levels. The lower level caches, upon receiving this message, moves the corresponding block to the head of 
the LRU chain. Although simple, the scheme generates huge amount of traffic to all levels of caches, since L1 hits 
are usually filtered away from lower levels during normal operation. The paper indicates that although this scheme is
not practical in any sense, it is perfect as an upper bound to see how well the other two schemes perform.

The second scheme, Early Care Invalidation (ECI), forces the core cache to explicitly request for a frequently accessed 
block before it is about to be evicted. ECI operates as follows. When a block P is to be evicted from a non-core cache, 
probably because it is at the bottom of the LRU chain, the cache controller selects the next block Q to be evicted
(e.g. the second bottom block in the LRU chain), and then evicts the block from the upper level cache (if it is cached;
Otherwise do nothing). The two eviction messages can be combined into one because the upper level cache will receive 
an invalidation anyway, so the amount of traffic barely change. The observation is that, if the second-last block 
in the LRU chain is a frequently accessed block, then after it has been evicted from the core cache, it is expected
that the core cache will access it shortly, which misses the core cache. When the cache miss is sent to the shared
cache, then very naturally, the block will be moved to the head of the LRU chain, which prevents it from being evicted
too soon. The drawback of this scheme, however, is that the cache block must be re-used in the core cache between the 
window from the eviction of P and the next eviction of Q. If the core cache access of block Q only happens after Q has
been evicted from the shared cache, this access will still be a miss as in the normal case.

