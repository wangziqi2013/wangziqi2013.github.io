---
layout: paper-summary
title:  "Relaxed Persist Ordering Using Strand Persistency"
date:   2020-12-27 21:19:00 -0500
categories: paper
paper_title: "Relaxed Persist Ordering Using Strand Persistency"
paper_link: https://ieeexplore.ieee.org/document/9138920
paper_keyword: NVM; Write Ordering; Strand Persistency; StrandWeaver
paper_year: ISCA 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes strand consistency and a hardware implementation, StrandWeaver, to provide a better persist 
barrier semantics and a more efficient implementation than current designs. Persist barriers are essential to NVM
programming as it orders store operations to the device, which is utilized for correctness in many logging-based 
designs. For example, in undo logging, log entries must reach the NVM before dirty data, and dirty data must be flushed
back before the commit mark is written. Similarly, in redo logging, redo log entries must be ordered before the commit
mark, which is then ordered before all dirty data.
On today's commercial architectures, these write orderings are expressed as persist barriers consisting of cache line
flush and memory fences. For example, on x86 ISA, a persist barrier consists of one or more clwb instructions for 
writing back dirty cache lines, and a sfence instruction after all clwbs.
clwb instructions are only strongly ordered with preceeding store instructions with the same target address, and memory
fence (either explicit or implicit) instructions. clwbs are neither ordered with other stores nor with each other.

The paper points out that a persist barrier implementation in the above form has two performance drawbacks. First,
persistence ordering is coupled with consistency ordering, meaning that the pipeline must be stalled before a dirty
block is fully flushed back to the NVM, blocking the commit of the following store operations even though these stores 
do not write into the NVM. Second, parallelism is severaly restricted, since only one or a few write operations can
be persisted in parallel before the sfence instruction due to the property of most NVM-related workloads. 
Current commercial NVM devices usually have a few persistence buffers internally, which supports multiple concurrent
operations for better throughput.

To address the above issues, this paper proposes strand persistency model, which relaxes some overly restricted ordering
requirements in today's persistence model, and enables a new programming model for writing NVM applications.
In the conventional persistence model, the execution or stores and cache line write backs are divided into "epochs"
by the store fence instructions. Store operations in the same epoch are unordered, but store operations on different 
epochs are guaranteed to be in the program order. 
