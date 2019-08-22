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

