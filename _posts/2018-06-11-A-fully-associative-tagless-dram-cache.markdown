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
  
As in-package DRAM modules are becoming available, its usage as a fast L4 cache has been studied extensively. 
Previous stydies suggest that DRAM cache cannot be organized in the same way as a SRAM cache for performance 
and storage reasons. In particular, keeping a tag array to track part of the physical addresses of cache lines 
is considered not feasible. There are several reasons. First, as the typical size of a DRAM cache is hundreds 
of megabytes or even several GBs, storing tags as an on-die SRAM array would be prohibitively expensive and induce 
high latency. Second, the tag array needs to be read and compared against the physical address of the accessed line. 
This operation is on the critical path of a cache lookup. Finally, even if there is a cheap and fast 
way of storing and accessing tags, caching data at 64 byte guanularity as SRAM cache does may not be beneficial,
as the locality is not fully exploited.

This paper proposes a tagless DRAM cache design, where tag comparison is omitted from the lookup path, and 
the cache is maintained at page granularity (e.g. 4KB). There are three major components in the tagless design:
a extended cache-address TLB (cTLB), a global inverted page table (GIPT), and a modified page table. 
All of these three are either easy to implement in hardware, or does not require significant effort to modify 
existing hardware. We introduce the three components in the following sections.

The cTLB is extends each entry with a cache address, which stores information for hardware circuits to locate
a DRAM cache block. Physical addresses also need to be maintained as in an ordinary TLB, as SRAM caches still 
uses physical address as tags. Since the cache block is of the same size as a page that the cTLB maps, only one 
cache address field is sufficient. We maintain an invariant that the DRAM cache must hold all pages mapped by the 
TLB. The remaining unmapped storage of the DRAM cache can be used as a victim cache. Eviction of cached blocks is 
not mandatory when an entry is evicted from the cTLB. The corresponding cache block can still be kept in the DRAM 
cache, continuing to exist as a victim block. On executing a memory instruction, the TLB is consulted to find the 
physical address and L4 cache address. If the first three levels miss, then the cache address is used to fetch the 
cache block from the DRAM cache. Thanks to the above mentioned invariant, it is guaranteed that as long as the cTLB 
has an entry for a page, the page must exist in the DRAM cache. If cTLB misses, then the page walker is invoked to 
traverse the page table and load the corresponding entry. We cover the details of the page table in the next paragraph.

The page table is modified such that the L4 status of a page is also reflected by the page table entry (PTE).
On a cTLB miss, the page walker traverses the page table as usual to find the PTE. The PTE is extended with three extra
bits: a Valid in Cache (VC) bit to indicate whether the page has been cached by the L4; a Non-Cachable (NC) bit
to indicate whether L4 should not be used for this page; a Pending Update (PU) bit which serves as a lock to synchronize
page walkers of different processors in a multicore systems. The page walker first checks the NC bit. If NC is set,
then the page will never be cached by L4, and it simply loads the physical address and returns. Otherwise, it checks the 
VC bit. If VC bit is clear, the page has not been loaded into the L4 cache. The page walker loads the physical address
in the PTE, allocates a block in L4, and then stores the . In the above process, the PU bit is used as a lock bit. 
Before any read or write operation is to be performed on the PTE, the page walker must spin on the PU bit if it is set, 
or set the bit atomically if it is clear. The PU bit is cleared after the operation has completed. 