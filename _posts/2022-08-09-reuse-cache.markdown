---
layout: paper-summary
title:  "The reuse cache: downsizing the shared last-level cache"
date:   2022-08-09 01:13:00 -0500
categories: paper
paper_title: "The reuse cache: downsizing the shared last-level cache"
paper_link: https://dl.acm.org/doi/10.1145/2540708.2540735
paper_keyword: Reuse Cache; RRIP; Decoupled Tag-Data
paper_year: MICRO 2000
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Reuse Cache, a last-level cache (LLC) design that selectively caches data only when they are
reused and thus saves storage. The design is based on the observation that most cache blocks in the LLC are useless
(i.e., will not see reference during their lifetime), and that even for useful blocks, cache hits are only concentrated 
on a small subset of them. 
