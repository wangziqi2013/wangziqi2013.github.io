---
layout: paper-summary
title:  "Rethinking TLB Designs in Virtualized Environments: A Very Large Part-of-Memory TLB"
date:   2018-05-05 19:27:00 -0500
categories: paper
paper_title: "Rethinking TLB Designs in Virtualized Environments: A Very Large Part-of-Memory TLB"
paper_link: https://dl.acm.org/citation.cfm?id=3080210
paper_keyword: POM-TLB
paper_year: 2017
---

This paper presents a design of L3 TLB that resides in DRAM rather than in on-chip SRAM. 
In general, a larger TLB favors virtualized workload, where a single virtual address translation 
may involve at most 24 DRAM references, known as nested or 2D page table walk (PTW). In addition, 
the reduced frequency of PTW also benefits ordinary workloads.

In order to 
reduce the numbre of costly DRAM accesses caused by virtualized workload 
