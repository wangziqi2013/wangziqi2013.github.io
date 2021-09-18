---
layout: paper-summary
title:  "BabelFish: Fuse Address Translation for Containers"
date:   2021-09-17 23:52:00 -0500
categories: paper
paper_title: "BabelFish: Fuse Address Translation for Containers"
paper_link: https://dl.acm.org/doi/10.1109/ISCA45697.2020.00049
paper_keyword: Virtual Memory; Linux; Paging; MMU; Containers; BabelFish
paper_year: ISCA 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
--- 

This paper proposes BabelFish, a virtual memory optimization that aims at reducing duplicated TLB entries and page 
table entries. BabelFish is motived by the fact that containerized processes often share physical pages and the
corresponding address mappings. On current TLB architectures, these mappings will be cached by the TLB as distinct
entries, because of the ASID field for eliminating homonym or expensive TLB flushes on context switches.
