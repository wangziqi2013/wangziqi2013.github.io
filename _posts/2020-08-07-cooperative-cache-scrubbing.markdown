---
layout: paper-summary
title:  "Cooperative Cache Scrubbing"
date:   2020-08-07 21:13:00 -0500
categories: paper
paper_title: "Cooperative Cache Scrubbing"
paper_link: PACT 2014
paper_keyword: Cache; Cache Scrubbing
paper_year: 
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes cooperative cache scrubbing, a technique for reducing cache-memory bandwidth. The paper points out
at the beginning that as computing infrastructures keep scaling up, the energy conssumption of main memory has become
a major part of total energy of the system. Each read and write operation will consume energy and increase heat dissipation. 
The paper observes, however, that not all traffic to and from the main memory are necessary. Some of them can be entirely
avoided given that software can convey extra information about the allocation status of cache lines to hardware. 

