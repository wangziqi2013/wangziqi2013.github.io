---
layout: paper-summary
title:  "A fully associative, tagless DRAM cache"
date:   2018-06-11 01:10:00 -0500
categories: paper
paper_title: "A fully associative, tagless DRAM cache"
paper_link: https://dl.acm.org/citation.cfm?id=2750383
paper_keyword: cTLB; DRAM cache; tagless
paper_year: ISCA 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

As in-package DRAM modules are becoming mature, its usage as a fast L4 cache has been studied for many
researchers. Previous stydies suggest that DRAM cache cannot be organized in the same way as a SRAM cache 
is for performance and storage reasons. In particular, keeping a tag array to track part of the physical 
addresses of cache lines is considered not feasible. There are several reasons. First, as the typical size
of a DRAM cache is hundreds of megabytes or even several GBs, storing tags as an on-die SRAM array would be 
prohibitively expensive and have high latency. Second, the tag array needs to be read and compared against
the physical address of the accessed line. This operation is on the critical path of a cache lookup.
This can make the latency of DRAM caches too large to be useful. Finally, even if there is a cheap and fast 
way of storing and accessing tags, caching data at 64 byte guanularity as SRAM cache does may not be beneficial,
as the locality is not fully exploited.

This paper proposes a tagless DRAM cache design, where tag comparison is omitted from the lookup path, and 
the cache is maintained at page granularity (e.g. 4KB). There are three major components in the tagless design. 
They are either easy to implement in hardware, or does not require significant effort to modify existing hardware.
We introduce the three components in the following sections.