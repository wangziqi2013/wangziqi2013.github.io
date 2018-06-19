---
layout: paper-summary
title:  "Energy Efficient Address Translation"
date:   2018-06-19 00:40:00 -0500
categories: paper
paper_title: "Energy Efficient Address Translation"
paper_link: https://ieeexplore.ieee.org/document/7446100/
paper_keyword: TLB; Redundant Memory Mapping; Segmentation; RMM; Lite
paper_year: HPCA 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Translation Lookaside Buffer (TLB) can become a significant source of heat and consumer of power in a 
system. Two types of energy usage are recognized. The first is static energy, which is a consequence of 
page walks and longer execution times due to TLB misses. The second is dynamic energy, which is the energy
consumed by the TLB circuit itself. Techniques that optimize TLB's miss ratio can reduce static energy by
having less page walk and execution time, decreasing the power consumption of the TLB. On the other hand, 
the dynamic energy may increase as a result of more complicated hardware.

This paper aims at optimizing the dynamic energy consumption of TLB by disabling ways if they are hardly
beneficial to performance.