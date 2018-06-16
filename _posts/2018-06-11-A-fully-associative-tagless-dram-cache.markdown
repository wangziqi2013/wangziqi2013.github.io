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
in the PTE, allocates a block in L4, and then stores the cache address in the physical address field. If the VC bit is 
already set, then the page walker just loads the "physical address", which is now the L4 cache address, and returns.
In both cases, the page walker populates the TLB entry with the cache address of the corresponding page. The MMU then
uses the cache address to locate the block and return data to the core. In the above process, the PU bit is used as a 
lock bit. Before any read or write operation is to be performed on the PTE, the page walker must spin on the PU bit if 
it is set, or set the bit atomically if it is clear. The PU bit is cleared after the operation has completed. The GIPT
is also modified to reflect the fact that one more TLB entry is allocated to point to the cached L4 copy. We cover GIPT 
in the next section.

The Inverted Global Pointer Table, GIPT, is indexed by cache addresses (do not require associative search). It maps 
a page in L4 cache to its physical address in the main memory, the address of the corresponding PTE, and a TLB residence 
vector. The TLB residence vector acts as a directory of the TLB entries. If the page stored in the cache address is 
accessible through a particular core's TLB, then the corresponding bit in the residence vector must be set. This vector 
is used to maintain coherence between TLB entries when a page table entry is modified. The GIPT serves as a global
directory for pages in the L4 cache. It also has a small free queue, which holds the cache address of cache lines that
are to be evicted in the background. When the number of free pages in the L4 cache drops below a threshold &alpha;, the 
cache controller will select a cache block not mapped by any TLB (assuming the range of all TLBs in the system cannot 
cover the entire L4; Otherwise TLB shootdown must also be performed), and put its cache address into the free queue.
A background hardware process then flushes the cache entry back to main memory if the entry is dirty. Freed cache 
blocks are chained together using a free list, the head of which is also part of the global information. By maintaining 
at least &alpha; free blocks, page walks will never be blocked because of the bandwidth limit on write backs.
The background write back process uses the GIPT to locate the PTE as well as the physical address of the cache block.
On a write back, the PTE is updated such that the cache address is replaced by the physical address. The VC bit is 
cleared to indicate that there is no cached copy in L4.

Always fetching the entire page into L4 cache can cause "over-fetching" problem. If the locality of access is low, 
the non-cachable bit in the PTE can be turned on by the OS. The page walker then ignores the L4 cache while performing
the page walk. The TLB is also extended with the NC bit, and it is loaded from the PTE during the page walk. Another 
similar problem that benefits from the NC bit is aliasing, where several different PTEs point to the same physical frame.
In this case, it is difficult for the page walker to figure out that whether the physical address has already been cached
by L4 without performing an associative search within the GIPT. The OS can simply turn off L4 caching on these pages, and 
force the system to fall back to tag-based caching scheme.

