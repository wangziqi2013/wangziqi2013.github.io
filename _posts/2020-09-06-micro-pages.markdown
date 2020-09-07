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


