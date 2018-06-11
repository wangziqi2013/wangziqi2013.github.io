---
layout: paper-summary
title:  "A fully associative, tagless DRAM cache"
date:   2018-06-11 01:10:00 -0500
categories: paper
paper_title: "A fully associative, tagless DRAM cache"
paper_link: https://dl.acm.org/citation.cfm?id=2750383
paper_keyword: cTLB; DRAM cache; tagless
paper_year: ISCA 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

As in-package DRAM modules are becoming mature, its usage as a fast L4 cache has been studied for many
researchers. Previous stydies suggest that DRAM cache cannot be organized in the same way as a SRAM cache 
is for performance and storage reasons. In particular, keeping a tag array to track part of the physical 
addresses of cache lines is considered not feasible. There are several reasons. First, as the typical size
of a DRAM cache is hundreds of megabytes or even several GBs, storing tags as an on-die SRAM array would be 
prohibitively expensive and have high latency. Second, the tag array needs to be read and compared against
the physical address of the accessed line. This operation is on the critical path of a cache lookup.
This can make the latency of DRAM caches too large to be useful. Finally, even if there is a cheap and fast 
way of storing and accessing tags, caching data at 64 byte guanularity as SRAM cache does may not be beneficial,
as the locality is not fully exploited.

This paper proposes a tagless DRAM cache design, where tag comparison is omitted from the lookup path, and 
the cache is maintained at page granularity (e.g. 4KB). There are three major components in the tagless design:
a extended cache-address TLB (cTLB), a global inverted page table (GIPT), and a modified page table. 
All of these three are either easy to implement in hardware, or does not require significant effort to modify 
existing hardware. We introduce the three components in the following sections.

The cTLB is extended with each entry a cache address, which stores information for hardware circuits to locate
a DRAM cache block. Physical addresses also need to be maintained, as SRAM caches still uses physical address 
as tags. Since the cache block is of the same size as a page that the cTLB maps, only one pointer is sufficient. 
We maintain an invariant that the DRAM cache must hold all pages mapped by the TLB. The remaining unmapped 
storage of the DRAM cache can be used as a victim cache. If an entry is evicted from the cTLB, the corresponding
cache block can still be cached in the DRAM cache, and continues to exist as a victim block. 
On a memory instruction, the TLB is consulted to find the physical address and L4 cache address. If the first 
three levels miss, then the cache address is used to fetch the cache block from the DRAM cache. Thanks to 
the above mentioned invariant, it is guaranteed that if the cTLB has an entry for a page, then the page 
must exist in the DRAM cache. If cTLB misses, then the page walker is invoked to traverse the page table and 
load the corresponding entry. We cover the details of the page table in its own section.