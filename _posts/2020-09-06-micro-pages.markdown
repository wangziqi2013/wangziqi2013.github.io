---
layout: paper-summary
title:  "Micro-Pages: Increasing DRAM Efficiency with Locality-Aware Data Placement"
date:   2020-09-06 23:49:00 -0500
categories: paper
paper_title: "Micro-Pages: Increasing DRAM Efficiency with Locality-Aware Data Placement"
paper_link: https://dl.acm.org/doi/10.1145/1735970.1736045
paper_keyword: Micro Pages; Virtual Memory; DRAM
paper_year: ASPLOS 2010
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Lowlight:**

1. This paper is not really doing clustering. Instead, it simply recognizes hot micro-pages from each page, and copies
   them to a small, concentrated area. This does not guarantee that micro-pages that are accessed together are always
   on the same row. In a worst case, frequent row buffer closing may still be required, if micro-pages are not placed
   optimally. Data placement itself should be a topic of this paper, but there is none.

2. The paper does not specify whether data migration happens in the background or foreground. If former, is the 
   overhead of blocking system execution and performing data migration counted towards the overhead? If latter, how
   does OS deal with data race with potential writes to the migrated page and data copy (you can set write permission
   for pages under migration, of course)?

3. The paper does not mention how the reserved space is maintained, i.e., how evictions happen? How OS / memory controller
   remembers which slot stores which micro page?

This paper proposes micro pages, an optimization framework for increasing row buffer hits on DRAM. The paper points out 
that DRAM row buffer hit rates are decreasing in the multicore era, because of the interleaved memory access pattern from
all cores. This has two harmful effects performance-wise. First, modern DRAM reads a row of data from the DRAM cells into
the DRAM buffer, which is latched for later accesses. If only a small part of the buffer is accessed before the next row
is read out, most of the energy spent pn row activation and write back is wasted, resulting in higher energy consumption.
Second, most DRAM controllers assume that locality within a row exist, and therefore, maintains the row in opened state
until the next request that hits a different row is served. This "Open Page" policy will cause extra latency on the 
critical path, since closing a row requires writing the row buffer back to the DRAM cells, which cannot be overlapped
with request parsing and processing after the current request has been completed. Lower locality implies that more 
page closing will be observed, incurring higher DRAM access latency.

One of the most important observations made by the paper is that, in a multicore environment, most accesses to pages are
clustered on smaller address ranges. As the number of cores increase, the observed locality on each DRAM row steadily 
decreases.
Micro-page solves the above problem by clustering segments from different OS pages that are frequently accessed to the same 
DRAM row. This requires a finer granularity than OS pages in order to only partially map a portion of a page. The 
paper proposes that the physical address page frames be further divided into smaller, 1KB "micro pages", which is the basic
unit of access tracking and data migration.

We first introduce the base line system. This paper assumes that the DRAM operates with open page policy, with the 
row size being 8KB. Virtual memory page sizes for both virtual and physical address spaces are 4KB. Micro-pages
are boundary-aligned, 1KB segments on the physical address space. The memory controller extracts bits 15 - 28 of a 32-bit 
physical address as the row ID. The rest of the bits are used as DIMM ID, bank ID, and column ID, the order of which is
unimportant. The paper assumes that the OS is aware of the underlying address mapping performed by the memory
controller, such that the OS can purposely place a micro page on a certain DRAM row, bank, and DIMM by combining these
components to form a physical address.

The micro-page desing has two independent parts: Usage tracking and data migration. The usage track component maintains
statistics on the number of accesses each physical page has observed. The access information is then passed to the data 
migration component, which decides micro pages that should be clustered together. The execution is divided into non-overlapping
epochs. During an epoch, statistics information is collected. At the end of the epoch, migration decisions are made based
on the statistics. Different migration policies can be implemented independent from data collection, granting better flexibility.

The statistics tracking is implemented as an array of counters in the memory controller. The paper suggests that 512
counters be used, each responsible for one 1KB micro page, which tracks 512KB of working set in total. The paper does
not specify the organization of the counter array, but the best guess is that they are organized as a CAM array, with
each entry associated with an address tag for lookup. When a request is served by the memory controller, the corresponding
entry is updated by incrementing the counter. If the entry does not exist, then an new entry is inserted, after evicting
an existing one (preferably the smallest one), if the array is full. The content of the array is also saved on context switch,
since it is also observed that memory access pattern changes across processes.

The paper proposes two mechanisms for data migration: One OS-based, and a memory controller-based. We first describe the 
OS-based approach. This approach requires the hardware and the OS to support 1KB micro pages. The MMU is modified to read
four base addresses, instead of one, from the page table entries. The paper does not elaborate on the page table organization,
but the general idea is that each 4KB page now is allowed to have four independent base addresses, by setting a mode bit
in the PTE. The old 4KB paging machanism is not changed, since it will still be used by most of the pages that do not
require migration. The TLB is also extended to add a few bits per entry in the address tag to support 1KB entry. 
During epoch execution, memory allocation still happens at 4KB granularity. 
At the end of the epoch, the OS scans the counter array on the memory controller, and decides which micro pages are 
frequently accessed, and should hence be migrated. The OS reserves the first 16 rows from each bank for placing micro pages,
allowing at most 4MB of data to be clustered. 
OS physical address map should mark addresses mapped to these rows as unusable. 
The OS then copies micro pages from their home location to a vacant slot in the reserved area, and updates page table
mapping only for that 1KB micro page (TLB shootdown should also be performed). 
If the reserved area is full, one of the existing entry is evicted back to its home location. The OS should therefore maintain
a table for all micro pages in the reserved area. This table should contain pointers to their original PTEs to assist evictions.

The second mechanism relieves the OS from the responsibility of maintaining multiple mappings for one 4KB page. In the 
second approach, the OS still runs on an abstraction of flat, non-micro paged physical address space, while the memory
controller implements address remapping. The memory controller manages a 4096 entry CAM array, with each entry storing
the home micro page address (aligned to 1KB boundaries) of data stored in the corresponding slot. Entries are mapped
to slots linearlly, as there are excatly 4MB / 1KB = 4096 slots in the reserved rows.