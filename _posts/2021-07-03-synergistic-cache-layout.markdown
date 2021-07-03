---
layout: paper-summary
title:  "Synergistic Cache Layout for Reuse and Compression"
date:   2021-07-03 06:32:00 -0500
categories: paper
paper_title: "Synergistic Cache Layout for Reuse and Compression"
paper_link: https://dl.acm.org/doi/10.1145/3243176.3243178
paper_keyword: YACC; Reuse Cache; FITFUB; First Use
paper_year: PACT 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes a cache insertion policy that increases actual block reuse by delaying the insertion of the data
block. The paper is motivated by the fact that, at LLC level, block re-usage is not as common as one may expect at 
higher levels of the hierarchy, mainly because locality has already been filtered out by higher level caches.
Traditional replacement algorithms such as LRU assume that blocks will be re-referenced shortly after being inserted,
and hence gives it low priority for replacement. In addition, the cache always defaults to an always-allocate policy,
i.e., a cache block is always inserted into the cache when it misses the LLC, assuming that the block will be 
referenced again in the future. 

