---
layout: paper-summary
title:  "Fundamental Latency Trade-offs in Architecting DRAM Caches"
date:   2019-08-31 22:46:00 -0500
categories: paper
paper_title: "Fundamental Latency Trade-offs in Architecting DRAM Caches"
paper_link: https://ieeexplore.ieee.org/document/6493623
paper_keyword: L4 Cache; DRAM Cache; Alloy Cache
paper_year: MICRO 2012
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Alloy Cache, a DRAM cache design that features low hit latency and low lookup overhead. This paper 
is based the assumption that the processor is equipped with Die-Stacked DRAM, the access latency of which is lower than 
conventional DRAM (because otherwise, directly accessing the DRAM on LLC miss is always better). The paper identifies 
several issues with previously published DRAM cache designs. 