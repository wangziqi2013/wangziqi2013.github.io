---
layout: paper-summary
title:  "Dynamic Dictionary-Based Data Compression for Level-1 Caches"
date:   2022-08-07 02:54:00 -0500
categories: paper
paper_title: "Dynamic Dictionary-Based Data Compression for Level-1 Caches"
paper_link: https://link.springer.com/chapter/10.1007/11682127_9
paper_keyword: Cache Compression; L1 Compression; Frequent Value Compression; Dynamic Dictionary
paper_year: ARCS 2006
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Dynamic Frequent Value Cache (DFVC), a compressed L1 cache design using a dynamically generated
dictionary. The paper is motivated by the ineffectiveness of statically generated cache as proposed in earlier works.
The paper proposes a dynamic dictionary scheme that enables low-cost dependency tracking between compressed data
and dictionary entry in which both dictionary entries and cache blocks periodically "decay" using a global counter.