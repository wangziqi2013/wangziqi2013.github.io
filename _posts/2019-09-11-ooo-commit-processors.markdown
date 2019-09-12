---
layout: paper-summary
title:  "Out-of-Order Commit Processors"
date:   2019-09-11 23:47:00 -0500
categories: paper
paper_title: "Out-of-Order Commit Processors"
paper_link: https://ieeexplore.ieee.org/document/1410064?arnumber=1410064&tag=1
paper_keyword: ROB; Microarchitecture
paper_year: HPCA 2005
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper explores the design space for out-of-order instruction commit in out-of-order execution, superscalar processors.
Conventionally, out-of-order execution processors have a FIFO reorder buffer (ROB) at the backend which is populated when 
instructions are dispatched to the backend. Instructions are inserted into the ROB in the original dynamic program order,
and remain there until the execution is finished. Instructions are only retired in the ROB when they are currently at the 
head of the ROB (i.e. the oldest uncommitted instruction). Instructions commit by writing their results back to the register 
file (in practice this can happen earlier than instruction commit), moving the store queue entry into the store buffer, or 
forcing the processor to restart on the correct path on a branch mis-prediction.

As the number of instructions in the instruction window keep increasing for better ILP, the ROB has become a bottleneck 
in the backend pipeline. There are two reasons for this. The first reason is that ROB forces instructions to commit 
in the program order, which decreases instruction throughput if the head of the ROB is a long-latency instruction,
such as loads that miss the L1 cache. The second reason is that the hardware cost for supporting an ROB with thousands
of entries is unacceptable with today's technology. The large ROB design simply cannot be achieved with reasonably 
energy and area budget.