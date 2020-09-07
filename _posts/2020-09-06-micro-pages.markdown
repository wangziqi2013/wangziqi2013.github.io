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
