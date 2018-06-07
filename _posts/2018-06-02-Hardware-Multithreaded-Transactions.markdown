---
layout: paper-summary
title:  "Hardware Multithreaded Transactions"
date:   2018-06-02 03:16:00 -0500
categories: paper
paper_title: "Hardware Multithreaded Transactions"
paper_link: https://dl.acm.org/citation.cfm?id=3173172
paper_keyword: Thread Level Speculation; MOESI; Coherence; HMTX
paper_year: ASPLOS 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---   

This paper proposes a cache coherence protocol for thread-level data speculation (TLDS).
The paper assumes a pipelined programming paradigm, where two threads, the producer and the consumer,
cooperate to finish a loop. The producer thread iterates through all stages of the loop and produces 
the context of the loop. For example, if the loop traverses a linked list and invokes a processing function 
for every node in the linked list, the producer thread will perform the iteration without invoking the processing function. 
Instead, it speculatively writes the pointer to the current node into a local variable, and then continues with the next node. 
Since speculative writes are private only to the iteration that produces, later on when the consumer thread begins
on the context, it could find the pointer to the node in the same local variable. One or more consumer threads 
then process the nodes in parallel by entering the corresponding iteration context first, and then invoking the 
processing function.

The goal of the new protocol is to achieve the following during the speculation. First, cache lines created by 
different iterations should be maintained separately without messing up with each other. 