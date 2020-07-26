---
layout: paper-summary
title:  "PageForge: A Near-Memory Content-Aware Page-Merging Architecture"
date:   2020-07-26 00:46:00 -0500
categories: paper
paper_title: "PageForge: A Near-Memory Content-Aware Page-Merging Architecture"
paper_link: https://dl.acm.org/doi/10.1145/3123939.3124540
paper_keyword: Page Deduplication; Page Forge
paper_year: MICRO 2017
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes PageForge, a hardware assisted page deduplication design which reduces cycle wastage and cache pollution.
Page deduplication has shown its potential in virtualized environments where different virtual machines, though strongly
isolated from each other, may use the same OS image and/or load the same shared library, exhibiting suffcient redundancy
for a deduplication scheme to significantly reduce storage consumption. 

The paper identifies that existing software-based page deduplication schemes have two problems: cycle wastage and cache
pollution. In order to find pages that contain duplicated contents, a background thread needs to continuously monitor 
pages and compare them to find chances for deduplication if they occur. This is a heavy-weight task, which is usually delegated
to a seperate thread on a dedicated core, and has non-negligible cycle overhead. 
In addition, since the background thread must read pages into the cache first before performing comparison. The resulting
cache pollution and bandwidth overhead may also negatively impact performance when the system load is high.
Although non-temporal memory accesses or non-cachable memory type can be employed to minimize the effect of cache
pollution, resource contention, such as convention on MSHRs, and the extra bandwidth imposed on the on-chip network,
still pose challenges for software solutions to solve.
