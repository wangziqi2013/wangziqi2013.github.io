---
layout: paper-summary
title:  "Residual Cache: A Low-Energy Low-Area L2 Architecture via Compression andd Partial Hits"
date:   2020-07-01 16:34:00 -0500
categories: paper
paper_title: "Residual Cache: A Low-Energy Low-Area L2 Architecture via Compression andd Partial Hits"
paper_link: https://dl.acm.org/doi/10.1145/2155620.2155670
paper_keyword: Cache; Compression; Residual Cache
paper_year: MICRO 2011
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Provides a new perspective that 2:1 compressed lines can be treated as a norm such that the cache only provides
   storage to these lines, and that those above 2:1 are exceptions and relative rare such that they can be treated
   differently by having a small residue cache

**Lowlight:**

1. Writing quality and presentation of ideas are extremely low

This paper proposes residual cache, a LLC design that features lower area and power overhead compared with conventional
set-associative caches. This paper points out that as the size of the LLC increases, the resulting higher power consumption
and area overhead can be problematic for mobile platforms. Reducing the cache size, on the other hand, may allievate 
these issues, but they increase execution time due to a less effective cache hierarchy, which also negatively impacts
power and performance.


