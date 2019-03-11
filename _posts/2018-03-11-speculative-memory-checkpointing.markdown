---
layout: paper-summary
title:  "Speculative Memory Checkpointing"
date:   2019-03-11 02:38:00 -0500
categories: paper
paper_title: "Speculative Memory Checkpointing"
paper_link: http://2015.middleware-conference.org/conference-program/
paper_keyword: Checkpointing
paper_year: Middleware 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Speculative Memory Checkpointing (SMC), which is an optimization to the classical incremental memory 
checkpointing technique using Operating System supported Copy-on-Write (COW). In the classical undo-based scheme, the 
checkpointing library relies on virtual memory protection and OS page table to detect whether a write operation is conducted 
on a certain page. Program execution is divided into consecutive epoches, which is the basic unit of recovery. During each 
epoch, the library tracks pages modified by the application, and copies the undo image to a logging area for recovery. 
Programmers use library primitives to denote epoch boundaries and restoration operations. On restoration, the library just
walks the undo log in reverse chronilogical order, and applies undo images to corresponding page frames, until the given epoch
to restore to has been . At the beginning of the epoch

This paper identifies potential problems