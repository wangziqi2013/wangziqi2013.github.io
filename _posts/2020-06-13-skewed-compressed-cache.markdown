---
layout: paper-summary
title:  "Skewed Compressed Caches"
date:   2020-06-13 22:27:00 -0500
categories: paper
paper_title: "Skewed Compressed Caches"
paper_link: https://dl.acm.org/doi/10.1109/MICRO.2014.41
paper_keyword: Compression; Cache Tags; Skewed Cache
paper_year: MICRO 2014
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes skewed compressed cache, a compressed cache design that features skewed set and way selection.
The paper identifies three major challenges of designing a compressed cache architecture. The first challenge is to
store compressed blocks compacted in the fixed size physical slot. Since compressed block sizes could vary significantly
based on the data pattern, sub-optimal placement of compressed data will result in loss of effective cache size and 
more frequent compaction operation on the data slot. 
