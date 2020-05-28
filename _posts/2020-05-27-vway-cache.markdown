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


