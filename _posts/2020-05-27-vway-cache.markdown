---
layout: paper-summary
title:  "The V-Way Cache: Demand Associativity via Global Replacement"
date:   2020-05-27 19:29:00 -0500
categories: paper
paper_title: "The V-Way Cache: Demand Associativity via Global Replacement"
paper_link: https://dl.acm.org/doi/10.1109/ISCA.2005.52
paper_keyword: v-way cache
paper_year: ISCA 2005
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes the V-Way Cache, a cache organization featuring lower set conflict miss rates and better replacement 
decisions. The paper points out that two factors affect cache hit rate and performance in set-associative caches. The 
first is that accesses are not evenly distributed over sets. Some cache sets are favored more than the rest. Such 
imbalance between set accesses may degrade performance, since these frequently accessed sets will observe higher-than-usual
cache miss rates. The second factor is local replacement. Traditional set-associative caches restrict replacement decisions
to be made within the current set, which is often quite small. Theoretically speaking, the optimal replacement decision
can be made with knowledge into the future by invalidating the line that is needed in the furthest future. 