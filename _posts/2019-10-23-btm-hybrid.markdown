---
layout: paper-summary
title:  "Using Hardware Memory Protection to Build a High-Performance, Strongly-Atomic Hybrid Transactional Memory"
date:   2019-10-23 12:10:00 -0500
categories: paper
paper_title: "Using Hardware Memory Protection to Build a High-Performance, Strongly-Atomic Hybrid Transactional Memory"
paper_link: https://dl.acm.org/citation.cfm?id=1382132
paper_keyword: BTM; UFO; Hybrid TM; HTM; STM
paper_year: ISCA 2008
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a hybrid transactional memory that provides both fast hardware transaction and strong semantics. 
The paper points out that neither HTM nor STM is feasible for real-life software development at the time of writing, because
HTM transactions are either bounded or have to pay extra cost to support unboundedness, while STM suffers from high
instrumentation and metadata overhead. Hybrid TM, as a seemingly suitable middle ground solution, can support both
fast HTM transaction and comprehensive and unbounded STM transaction, but designing one is still challenging. 