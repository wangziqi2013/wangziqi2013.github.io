---
layout: paper-summary
title:  "Opportunistic Compression for  Direct-Mapped DRAM Caches"
date:   2021-06-21 03:00:00 -0500
categories: paper
paper_title: "Opportunistic Compression for  Direct-Mapped DRAM Caches"
paper_link: https://dl.acm.org/doi/10.1145/3240302.3240429
paper_keyword: DRAM Cache; Opportunistic Compression; Alloy Cache
paper_year: MEMSYS 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes an opportunistic compression scheme for DRAM caches. The paper observes that direct-mapped DRAM
cache designs, such as the Alloy Cache, suffers from higher miss rate than conventional set-associative DRAM caches,
due to its lower associativity and the resulting possibility of cache thrashing. 
Despite the simpler access protocol and less metadata overhead, this can still hurt performance.

Prior proposals already considered compression as a way of increasing logical associativity. This, however, introduces
two issues. The first issue is that increased associativity requires more metadata bits and tags to be maintained.
Besides, the index generation function is also changed, which incurs non-trivial design changes.
Second, this somehow offsets the metadata and latency benefit of Alloy Cache, since the design goal of Alloy Cache 
is simplicity and low-latency access.
