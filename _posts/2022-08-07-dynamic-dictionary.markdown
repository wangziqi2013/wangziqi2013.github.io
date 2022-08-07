---
layout: paper-summary
title:  "Dynamic Dictionary-Based Data Compression for Level-1 Caches"
date:   2022-08-07 02:54:00 -0500
categories: paper
paper_title: "Dynamic Dictionary-Based Data Compression for Level-1 Caches"
paper_link: https://link.springer.com/chapter/10.1007/11682127_9
paper_keyword: Cache Compression; L1 Compression; Frequent Value Compression; Dynamic Dictionary
paper_year: ARCS 2006
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. The major challenge of implementing dynamic dictionaries is to preserve entries that are still being
used from eviction. In other words, data dependency from cache blocks to dictionary entries must be preserved 
in some way.

2. This paper proposes using decay period to evict both "dead" blocks that have not been accessed for a 
long period, and to evict dictionary entries that are not being used.
The essence is that when a block is being used, all dictionary entries that are used to compress the block
is refreshed (i.e., will not be evicted at the end of the decay period).
Data dependency is tracked at the decay period boundary in a similar way to epoch-based garbage collection.

**Comments:**

1. Even with decaying, it is still possible that the dictionary is fully utilized, and no entry can be evicted.
In this case, how to insert new entries? Does not insertion simply fail?

This paper proposes Dynamic Frequent Value Cache (DFVC), a compressed L1 cache design using a dynamically generated
dictionary. The paper is motivated by the ineffectiveness of statically generated cache as proposed in earlier works.
The paper proposes a dynamic dictionary scheme that enables low-cost dependency tracking between compressed data
and dictionary entry in which both dictionary entries and cache blocks periodically "decay" using a global counter.

The paper begins by recognizing dictionary compression as an effective method for improving L1 access performance.
L1 caches are latency sensitive as it is directly connected to the CPU. L1 cache compression therefore must use a
low-latency decompression algorithm such that the access latency of compressed blocks is not affected.
Dictionary compression is an ideal candidate under this criterion, because decompression is simply just reading
the dictionary structure (which can be implemented as a register file) using the index.

Previous works (as of the time of writing), however, only adopts static dictionary design, where the dictionary is 
generated beforehand by profiling the top K most frequent values in the workload memory. 
After the top K values are is generated, it will be loaded into the hardware dictionary, and then used throughout 
the rest of the execution.
While such a design greatly simplifies the dictionary logic, it has severe usability problems. First, generating 
the dictionary entries in software requires profiling runs, and is hence cumbersome to deploy.
Second, the dictionary is only sampled from a single application's memory image, while in reality, the values 
will be a mixture from different applications running on the same machine. The dictionary, however, is not 
context sensitive, and cannot adapt to multiple contexts running in the system.
Lastly, many applications exhibit phased behavior. Values samples from one phase, despite being representative 
for that phase, may not be representative for other phases. This behavior can render the dictionary entries mostly 
useless and largely invalidate the statically generated dictionary.

A hardware dynamically-generated dictionary, on the other hand, does not have the above issues, because the 
hardware can automatically and continuously monitor the workload's data pattern, and update the dictionary
contents according to the most recent observed values, rather than based on a small number of static samples.
The major challenge is therefore to determine how and when to evict dictionary entries.
Entry eviction is necessary for dynamic dictionary designs, because for large workloads, the dictionary is likely
fully utilized. Being able to evict less used entries from the dictionary is a critical part for adapting to the 
workload's data pattern.

The paper points out, however, that dictionary entry eviction cannot be done arbitrarily. If an entry is evicted
while there are still cache blocks compressed with the entry, then the cache block data will be corrupted, because
the block cannot be restored to its original uncompressed content.
Maintaining cross references between dictionary entries and cache blocks would also be a bad decision, because of 
the intolerable metadata cost.

To address the challenge, the paper proposes using the decay cache design, in which cache blocks are proactively
evicted after a long period of non-activity, instead of on-demand as in a regular cache.
Dictionary entries are also evicted by decaying, with the same decay parameter as cache blocks. 
The system maintains the invariant that a dictionary entry will remain valid, as long as any cache block
using the entry is accessed at least once during the last decay period. 


