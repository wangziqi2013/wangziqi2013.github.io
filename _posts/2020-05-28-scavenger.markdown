---
layout: paper-summary
title:  "Scavenger: A New Last-Level Cache Architecture with Global Block Priority"
date:   2020-05-28 22:34:00 -0500
categories: paper
paper_title: "Scavenger: A New Last-Level Cache Architecture with Global Block Priority"
paper_link: https://ieeexplore.ieee.org/document/4408273/
paper_keyword: Scavenger; Priority Queue; Heap
paper_year: MICRO 2007
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Scavenger, a last-level cache (LLC) design that features a regular cache and a priority heap as victim
cache. The paper points out at the beginning that as cache sizes increase, doubling the size of a cache can only bring 
marginal benefit by reducing the miss rate. In the forseenable future where more transistors can be integrated within the
same area and power budget, existing cache architectures may not scale well.

The paper makes one critical observation that most LLC cache misses (it was actually L2 at the time of writing) are on
addresses that have been repeatedly accessed in the past, i.e. some addresses are referenced by the upper level on a regular
basis after they were evicted. 