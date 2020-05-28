---
layout: paper-summary
title:  "The V-Way Cache: Demand Associativity via Global Replacement"
date:   2020-05-27 19:29:00 -0500
categories: paper
paper_title: "The V-Way Cache: Demand Associativity via Global Replacement"
paper_link: https://dl.acm.org/doi/10.1109/ISCA.2005.52
paper_keyword: v-way cache
paper_year: ISCA 2005
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes the V-Way Cache, a cache organization featuring lower set conflict miss rates and better replacement 
decisions. The paper points out that two factors affect cache hit rate and performance in set-associative caches. The 
first is that accesses are not evenly distributed over sets. Some cache sets are favored more than the rest. Such 
imbalance between set accesses may degrade performance, since these frequently accessed sets will observe higher-than-usual
cache miss rates. The second factor is local replacement. Traditional set-associative caches restrict replacement decisions
to be made within the current set, which is often quite small. Theoretically speaking, the optimal replacement decision
can be made with knowledge into the future by invalidating the line that is needed in the furthest future, regardless of 
the set it resides in. An sub-optimal but often sufficient decision can also be made while looking into the past and 
select the least recently accessed lines under the assumption that past access patternn also indicates the future. 
Both models are not practical in modern caches, since this would require a fully associative cache in which an address
can be mapped to any data slot. Expanding associativity is also unacceptable in many cases, since they most likely would
only marginally increase hit rate, at the cost of increased power consumption and larger decoder to the SRAM array.

Increasing the number of sets is also a viable way of increasing cache hits. The problem is that this essentially
doubles the storage cost of the cache, not to mention increased on-chip area dedicated to larger decoding and 
accessing logic. One observation is that tag storage only contributes, by a small fraction, to a cache's total area and 
energy consumption. The V-Way cache design doubles the number of tags while keeping the number of data slots unchanged,
as we will see below.

As discussed in the previous section, V-Way Cache only doubles the number of tags while keeping the number of data slots
unchanged. This is similar to virtual memory system where the virtual address space is larger than physical address space.
In such a system, the virtual address space can never be fully populated, since the maximum number of active pages allowed
will not exceed the capacity of the physical address space. This design has the benefit of more flexible resource management.
When multiple processes share the same physical memory, virtual address mapping creates the illusion that each of the process
have exclusive permission to the resource, while the actual resource management can divide resource between processes
based on demands, or even forces barely used pages of some other processes to be evicted to the disk. 
This works as long as each process only uses part of the physical resource available.

The same reasoning holds true for V-Way cache, except that we treat individual sets as processes in the above discussion,
and treat data slots as physical address space.
The overall idea is that, by doubling the number of tags on each way without increasing the number of data slots,
the cache controller could temporarily "borrow" data slots from other under-utilized sets to fulfill memory accesses
on a frequently accessed set. This is similar to how a virtual memory manager evicts a less used page of other 
processes to make space for a frequently accessed page of the current process. As long as set accesses are skewed,
this will create an illusion that some sets are larger than the rest.

The actual V-Way hardware is discussed as follows. First, the number of tags are doubled, and one more bit is 
used to index the tag array. As an alternative (not mentioned by the paper, but is interesting to consider),
sets are still indexed using the same number of bits, but the number of ways within the set is doubled, such
that more tags are read for address comparison after indexing the set. The former layout has the advantage of 
less tag comparison logic and power consumption, but statically distributes addresses over the two individual sets.
This might be ineffective if the access skew is not caused by the extra high index bit (i.e. one of the two sets still
see more accesses than the other). The paper assumes the former mainly because of the observation that most sets 
will have free tags anyway (due to under-provisioning of data slots).
Second, data slots are decoupled from tags. This is necessary for the under-provisioning design to work, just as in 
virtual memory systems physical pages are not statically bound to virtual page frames. 
The V-Way Cache allows any data slot to be mapped by any tag, such that data slots can be "borrowed" from other sets.
To this end, there is a "forward pointer", or FPTR field for every tag slot indicating the data slot it maps to.
Similarly, data slots are organized as a linear array (implemented as a SRAM register file), each having a "backward 
pointer", or BPTR, pointing to the tag that maps the data slot. The cache controller maintains the invariant that
FPTR and BPTR must always mutually point to each other. This design change also implies that tag and data slot accesses
must be serialized. Although this may increase acceass latency by a few cycles, since some caches allow parallel 
access of tag and data, the paper suggests that for L2 caches this is not an issue, and some commercial designs already
serialize these two for lower power consumption.

The V-Way cache works as follows. On a cache access request, the tag array is indexed using the lower middle bits of 
the requested address. Once the set is located, tags are read in parallel and compared as in a regular cache. A cache
hit is signaled if one of the address tags match, and the corresponding FPTR is used to access the data register file,
from which cache data is returned. Cache misses, however, are more complicated than in a regular cache. There are 
two cases for cache misses. In the first case, the tag array is full, and no more tags can be inserted into the set.
In this case, a local replacement algorithm for tags are used, and one of the tags in the set is evicted. The 
replacement algorithm can be any conventional algorithm, and it only makes local decision. The data slot is also 
recycled for the new incoming cache line. Neither FPTR nor BPTR are mofidied, since the tag-data slot mapping does 
not change. In the second case, there is at least one empty slot in the set. The paper argues that this is more common,
since data slots are under-provisioned. In this case, no tag needs to be evicted. The cache controller, however, should
find an empty data slot in the data array which is then mapped by an arbitrary empty tag in the set. If there is already
an empty data slot, it will be used. Otherwise, the replacement algorithm evicts a data slot based on global access
information, rather than the set's local information. Once the decision is made, the tag that currently maps the data slot
will be invalidated by following the BPTR of the selected data slot, and clearing the valid bit for that tag. The data
slot is then recycled by setting its BPTR to the empty tag. The FPTR of the empty tag is also set to the data slot.

The above discussion suggests that two replacement algorithms determine the eviction victim in the two cases respectively.
Local decisions are made when there is not enough number of tags in the current set, while global decisions are 
made when there is an empty tag, but a new data slot is required. Global decisions can always result in a better
replacement strategy, since they consider all cache lines in the cache, rather than only a small subset of them. 
This is also similar to virtual memory managent with multiple processes: If another process has in-memory page
that is rarely used, it is better to evict that page to serve the page fault of the current process, rather than
evicting a page in the current process's working set, which may turn out to be a more frequently accessed page than
the other candidate.

The paper proposes a reuse-count based global eviction algorithm for V-Way Cache. V-Way Cache is proposed for L2 and LLC
level, which only see a filtered trace of all memory accesses. In other words, locality of access is significantly lower
in L2 and LLC than in an L1 cache. Based on this observation, traditional algorithms such as LRU do not work well for 
L2 and LLC, since an address being accessed in the recent past does not not necessarily imply that it will also be likely
accessed in the future, as most accesses will just hit the L1. 
Instead of using last access time, access frequency is a better matric for measuring whether an address is likely to
be used in the future, since access frequency in the past does imply similar frequency in the future. 



