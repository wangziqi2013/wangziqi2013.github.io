---
layout: paper-summary
title:  "Efficient Register Renaming and Recovery for High Performance Processors"
date:   2019-09-13 21:18:00 -0500
categories: paper
paper_title: "Efficient Register Renaming and Recovery for High Performance Processors"
paper_link: https://ieeexplore.ieee.org/document/6558839
paper_keyword: ROB; Microarchitecture; Register Renaming
paper_year: VLSI 2014
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a hybrid register renaming scheme using both RAM and CAM to achieve low latency, low power consumption
and fast branch misprediction recovery. Conventional register renaming schemes either use RAM-based or CAM-based mapping 
table to encode the logical-to-physical relation. The paper observes that, however, that both schemes have inefficiencies
that can become the bottleneck of the pipeline. For RAM-based design, branch misprediction recovery and precise exception
both require that the mapping table be restored precisely to a previous point during execution. Modern pipelined processors, 
however, allow renaming of speculative instruction in the frontend to be performed in parallel while the branch (or faulty) 
instruction is still executed in the backend. The changes made by these mis-speculated instructions must be undone before 
the branch target can be fetched to avoid using the worng physical register. 