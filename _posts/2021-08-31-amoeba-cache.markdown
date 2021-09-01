---
layout: paper-summary
title:  "Amoeba-Cache: Adaptive Blocks for Eliminating Waste in the Memory Hierarchy"
date:   2021-08-31 23:46:00 -0500
categories: paper
paper_title: "Amoeba-Cache: Adaptive Blocks for Eliminating Waste in the Memory Hierarchy"
paper_link: https://dl.acm.org/doi/10.1109/MICRO.2012.42
paper_keyword: Amoeba-Cache; Tag-less Cache
paper_year: MICRO 2012
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Amoeba Cache, a tag-less cache architecture that supports multiple block sizes.
The paper is motivated by the fact that in conventional caches, it is often the case that spatial locality within a 
block is low, such that the block is underutilized during its lifecycle between fetch and eviction.
This phenomenon wastes bus bandwidth, since most of the contents being transferred on the bus and stored in the data 
array will be unused.

