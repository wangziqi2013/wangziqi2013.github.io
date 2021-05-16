---
layout: paper-summary
title:  "Hippocrates: Healing Persistent Memory Bugs without Doing Any Harm"
date:   2021-05-15 21:43:00 -0500
categories: paper
paper_title: "Hippocrates: Healing Persistent Memory Bugs without Doing Any Harm"
paper_link: https://about.iangneal.io/assets/pdf/hippocrates.pdf
paper_keyword: NVM; Bug Finding; Hippocrates
paper_year: ASPLOS 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents Hippocrates, a bug-fixing utility for NVM-based applications.
The paper notices that persistence-related bugs (durability bugs) in NVM oriented applications are hard to find 
but easy to fix.
Existing tools are often capable of finding write ordering violations in dynamic execution traces, but not able
to fix them automatically. 
Some other tools are targeted at fixing general bugs in application code, but they do not guarantee the eventual
correctness of the program, or may introduce new bugs.
Hippocrates closes the gap by proposing a few template fixes for certain classes of bugs found in NVM applications,
and a mechanism for applying these bug fixes automatically.

This paper assumes a x86-like persistence model. NVM storage is mapped to application process's virtual address space
such that they can be accessed with regular loads and stores just like DRAM.
Data items in the persistent address range are cached by the hierarchy just like normal data, introducing the 
consistency problem between the hierarchy and the NVM device on a system crash, at which time dirty data that 
belong to the persistence range but not yet flushed back to the NVM will be lost, meaning that a subset of 
stores will be lost, and it is unknown which store operations are lost. 
Programmers need to "fortify" the persistence semantics by inserting special primitives to enforce write ordering,
with which writes to the NVM device would be guaranteed to be ordered.
Based on the write ordering abstractions, many mechanisms can be applied to further built higher level semantics
such as transactional semantics.


Hippocrates limits its scope to three classes of common bugs that are found in applications. The first class is 
missing flushes, which is caused by programmers forgetting to insert cache line flush primitives after data is
modified, but before the memory fence primitive. 
