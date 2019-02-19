---
layout: paper-summary
title:  "Hiding the Long Latency of Persist Barriers Using Speculative Execution"
date:   2019-02-19 17:19:00 -0500
categories: paper
paper_title: "Hiding the Long Latency of Persist Barriers Using Speculative Execution"
paper_link: https://ieeexplore.ieee.org/document/8192470
paper_keyword: NVM; Persist Barrier; Speculative Execution
paper_year: ISCA 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---  

This paper proposes speculative persistence, a microarchitecture technique that allows processors to execute past a 
persistence barrier. A persistence barrier is a special instruction sequence that stalls the processor until previous
cached store operations are acknowledged by the memory controller. It is particularly essential in NVM applications
where the system state is persisted onto the NVM to enable fast crash recovery. Many existing proposals use undo
logging, where the value of data items (e.g. cache line sized memory blocks) are first recorded in a sequential log
before they are modified by store operations. On recovery, the undo log entries are identified, and partial modifications 
are rolled back by re-applying all undo log entries to the corresponding addresses. 


