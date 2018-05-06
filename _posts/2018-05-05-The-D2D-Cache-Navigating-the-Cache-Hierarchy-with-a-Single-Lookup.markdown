---
layout: paper-summary
title: "The Direct-to-Data (D2D) Cache: Navigating the Cache Hierarchy with a Single Lookup"
date: 2018-05-05 21:25:00 -0500
categories: paper
paper_title: "The Direct-to-Date (D2D) Cache: Navigating the Cache Hierarchy with a Single Lookup"
paper_link: https://dl.acm.org/citation.cfm?id=2665694
paper_keyword: D2D Cache; TLB
paper_year: 2014
---

This paper presents an elegant solution for solving the problem of having to probe all levels of 
the cache when a miss to DRAM occurs. Essentially this is totally unnecessary and wastes cycles. The 
problem we have here is that L1 cache is not sufficient to tell whether a cache line will miss the next level,
either L2 or L3. The status of miss or hit in lower levels will remain unknown before these caches are
probed. To solve the problem, instead of having the processor probe L1, L2 and L3 caches in a row (which 
is unnecessarily serialized), the exact location of a line is stored in the TLB. Every time a virtual address
is translated, in addition to finding the physical address associated with an entry, the TLB also 
returns the location of the line, including its cache level and set ID. Indices are always extracted from
the virtual or physical page number depending on whether the cache is virtually or physically indexed.