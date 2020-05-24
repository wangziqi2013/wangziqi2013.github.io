---
layout: paper-summary
title:  "Decoupled Sector Caches: Conciliating Low Tag Implementation Cost and Low Miss Ratio"
date:   2020-05-24 00:07:00 -0500
categories: paper
paper_title: "Decoupled Sector Caches: Conciliating Low Tag Implementation Cost and Low Miss Ratio"
paper_link: https://ieeexplore.ieee.org/document/288133/
paper_keyword: Sector Cache
paper_year: ISCA 1994
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes decoupled sector cache. Sector cache has been proposed long before this paper as a way of reducing 
tag storage. Conventional caches statically bind one data slot to one tag slot, such that when the tag is assigned an 
address, the corresponding data block is always fetched from the lower level. Such organization dedicates non-negligible 
storage to store address tags, which does not contribute to processor performance (note that this paper was published in
1994, at which time transistors are not as dense as it is today). This is especially true for caches with shorter lines.
For example, if the cache line size is 16 bytes as in MIPS R4000 architecture, the 24 bit tag cost can be as large as 
18.75%. The paper also points out that increasing cache line size can effectively improve the utilization of on-chip
SRAM storage. This, however, has negative effect such as increased bandwidth usage per transaction and possibilities of 
false sharing in the case of coherence.

Sector caches use larger-than-usual block size without introducing excessive data transfer and coherence invalidation 
by allowing a large cache line to be further divided into smaller units, called "sectors". Sectors are the basic
unit of data transfer and coherence just like a regular cache line. The address tag of the sector, however, is only
implied by the tag of the entire block and its index within the block. Given a sector size S, index I, and tag address T,
the implied address of the sector is T + S * I, i.e. all sectors in a cache block are linearly mapped to the underlying 
address space.
