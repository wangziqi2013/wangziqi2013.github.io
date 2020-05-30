---
layout: paper-summary
title:  "Capturing Dynamic Memory Reference Bahavior with Adpative Cache Topology"
date:   2020-05-30 11:00:00 -0500
categories: paper
paper_title: "Capturing Dynamic Memory Reference Bahavior with Adpative Cache Topology"
paper_link: https://dl.acm.org/doi/10.1145/291006.291053
paper_keyword: Cache; Group Associative
paper_year: ASPLOS 1998
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes group-associative cache, a direct-mapped cache design that dynamically adjusts association relationships 
between sets. The paper observes that cache accesses are often skewed in a way that many accesses actually happen to a
limited subset of all sets in the cache. This inevitably divides the cache storage into frequently accessed lines and 
infrequently accessed lines, or "holes". The existence of holes negatively impacts cache performance, since they could 
have been evicted by a global ereplacement policy, and reused for hosting those frequently accessed lines.


