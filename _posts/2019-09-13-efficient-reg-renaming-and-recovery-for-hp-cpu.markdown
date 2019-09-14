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
the branch target can be fetched to avoid using the worng physical register. For CAM-based design, the renaming state before
the branch instruction can be restored easily in constant time by checkpointing the renaming table into a checkpoint buffer.
When the branch is known to be mispredicted, the checkpoint is copied to the renaming table, which does not require walking
the ROB, but adds extra checkpoint buffer cost. In addition, register renaming needs to access the multi-ported CAM, the 
latency and power consumption of which can be large.

The paper reviews three different schemes in detail for RAM-based renaming algorithm. In such a design, A RAM structure 
indexed by the logical register number is used as the mapping table. For every logical register, there is an entry in
the RAM structure which stores the physical register mapped to this entry. A free list bit vector maintains currently
unused physical registers. When an instruction is decoded, the renaming logic first reads the physical register corresponding
to the source operands, and then allocate a new physical register for the destination logical register. The mapping table
entry for the destination register is updated to reflect the change 