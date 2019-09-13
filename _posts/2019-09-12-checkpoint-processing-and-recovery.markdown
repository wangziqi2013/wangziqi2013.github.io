---
layout: paper-summary
title:  "Checkpoint Processing and Recovery: Towards Scalable Large Instruction Window Processors"
date:   2019-09-12 09:09:00 -0500
categories: paper
paper_title: "Checkpoint Processing and Recovery: Towards Scalable Large Instruction Window Processors"
paper_link: https://ieeexplore.ieee.org/document/1253246
paper_keyword: ROB; Microarchitecture; Register Renaming
paper_year: MICRO 2003
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a ROB-less microarchitecture design which uses snapshots and register reference counting to
replace the regular ROB-based in-order commit scheme. The design decision was made based on the fact that future 
generations of processors must have large instruction windows to exploit program ILP. The paper identifies two
factors that may affect the performance of an out-of-order processor with ROB and in-order commit. 