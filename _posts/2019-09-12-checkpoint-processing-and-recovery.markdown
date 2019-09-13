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
factors that may affect the performance of an out-of-order processor with ROB and in-order commit. The first factor
is branch misprediction recovery time. When the processor mis-speculates on a wrong path, the branch instruction
should be executed and the execution be recovered from the current path as quickly as possible. This, however, is not
always possible with in-order commit, due to the fact that the register renaming table must be restored to the 
exact state before the branch instruction, after which recovery can begin (e.g. flush the pipeline, invalidate 
instructions on the wrong path, and load the PC with the correct path). The longer this takes, the larger the 
penalty of misprediction will be. For a large ROB, as we will see in the following paragraphs, the cost of restoring
the renaming table to a previous state proportionally grows with the ROB size. The second factor is the number of 
physical registers. As the number of in-flight instructions increase in the instruction window, the number of 
physical registers needed to hold the temporary values also increase. Simply adding more registers into the register file
does not always work, since the register file access time is often on the critical path. In addition, register files are 
usually multi-ported. Adding more registers is likely to incur intolerable area and power overhead of the access logic.

