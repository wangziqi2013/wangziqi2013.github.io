---
layout: paper-summary
title:  "EveryWalk’s a Hit: Making PageWalks Single-Access Cache Hits"
date:   2022-07-24 03:51:00 -0500
categories: paper
paper_title: "EveryWalk’s a Hit: Making PageWalks Single-Access Cache Hits"
paper_link: https://dl.acm.org/doi/abs/10.1145/3503222.3507718
paper_keyword: TLB; Virtual Memory; Page Walk
paper_year: ASPLOS 2022
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Comments:**

1. With flattened page table design, how are TLB shootdowns affected? On a related question, how is coherence 
on the PWC change? I would imagine it not be any issue, because the TLB always stores the mapped data page size
(rather than page table page size), and PWC is already designed to handle different prefixes.

2. Is it possible to allow non-aligned huge pages for page table pages? I mean, the current 8-byte page table 
entries have enough number of bits to address the next level in 4KB granularity. I did not see any problem
of not enforcing alignment for huge pages. Although this may complicate OS's buddy allocator, and I think there
must be a good reason that huge data pages must be aligned.

This paper proposes a novel page table and MMU co-design that reduces the overhead of address translation misses
on large working sets.
The paper is motivated by the fact that today's application generally has working sets at GB or even TB scale, 
but the capability of hardware to cache translation fails to scale proportionally. 
As a result, address translation misses becomes more frequent, and becomes more and more of a performance bottleneck.
The situation is only worsened by the introduction of virtualization, which requires a 2D page table and nested 
address translation, and the five-level page table that comes with the bigger virtual address space.
This paper seeks to improve the performance on address translation from two aspects: (1) Reducing the number of 
steps in page table walk by using huge pages for page tables, and (2) Reducing the latency of each step of 
page table walk with better caching policies.

The paper assumes a x86-like system with four levels of page tables, but does not exclude other possible designs
such as five-level page tables. 
Address translations are performed by the two-level TLB structure, and when the TLB misses, a page walk is conducted
to retrieve the address translation entry from the page table in the main memory.
The MMU is assumed to have page walk caches (PWCs) that store the intermediate results of the page walk. These PWCs 
are indexed using the index bits that lead to the intermediate levels.
When the PWC misses, the page table walker will attempt to retrieve the entry from the cache hierarchy.
If the translation entry is cached by the hierarchy, the page table walker can still avoid a main memory access
by reading the entry from the cache.
Otherwise, the entry is read from the main memory, and inserted into both the cache hierarchy and the PWCs.

The design is based on two critical observations.
The first observation is that existing radix tree-based page table designs always map radix nodes in 4KB granularity,
which is also the minimum unit supported by address translation. While larger granularity page mapping for data
pages are available as huge pages in the form 2MB and 1GB pages, these huge pages are not available 
for page tables.
The second observation is that, when the working set is large, or when access locality is low, it is usually 
the case that both data and translation entries have high cache misses, and hence both constitute performance
bottlenecks.
However, compared with data, translation entries have a much smaller data footprint, because an 8-byte entry
can map at least 4KB of data, a 1:512 ratio.
The paper concludes, therefore, that when the hierarchy suffers high miss rates for both data and the TLB, it is 
generally much more cost-effective to dedicate more caching storage to translation. 
In fact, according to the paper's calculation, for 8GB of data, the translation entry will be approximately 16MB,
which is smaller than a typical LLC on server-grade CPU chips. 
It is therefore theoretically possible to store all translation entries of the working set in the LLC, resulting in
100% hit rate of page walks, potentially without reducing data hit rate by much (if data access locality is low).

The paper even conducted a proof-of-concept experiment by running a large workload on one core, and starting another 
thread on a separate core that repeatedly accesses the translation entries to make sure that these entries are 
always warm in the shared LLC. With this simple technique alone, the paper observes 5% performance increase of the 
former thread, despite the extra memory bandwidth consumed by the software approach, proving the correctness
of the second observation above.

To address the first observation, the paper proposes flattened page table, where two or three consecutive levels 
of the radix tree are merged to create larger nodes that are backed by huge pages. 
For example, on a four-level page table, level 4 and level 3 could merge to become a single level,
requiring 18 bits to index, and all entries are stored in a 2MB huge page, and these entries point to
the level 4 entry.
Similarly, level 2 and level 1 could merge in the same manner, reducing the total number of steps in the 
page walk from four to two.
Alternatively, the paper suggests that level 3 and level 2 can merge, which reduces the number of steps
by one, but still beneficial.
Merging three levels into one is also possible, which creates 1GB huge pages, and reduces the number of steps
from four to two.

Page table flattening is controlled by the OS, and can be carried out dynamically at a per-entry granularity
(i.e., whether or not the next level is merged is encoded in the parent entry). 
This is important, because by
using huge pages to store page table entries, the OS risks not being to find an aligned physical memory slot
despite still having abundant fragmented physical memory.
The paper also notes that, if level 1 and level 2 are merged, then mapping 2MB data pages would require 512
consecutive entries, instead of one, to be set up in the 2MB page table page.

In order to support page table flattening, the paper proposes adding two extra bits per entry as well as to
the root pointer (e.g., CR3 on x86) to indicate whether the next level is merged, and what is the page size
of the next level. The page table walker can then generate addresses using different bit slices from the virtual
address to be translated based on this piece of information.
