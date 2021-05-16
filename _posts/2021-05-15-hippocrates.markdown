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
This paper assumes two primitives: cache line flush (clflush), and store fence (sfence).
The former forces a cache block to be written back to its backing device, but are not strongly ordered with each other
(i.e., different flushes may not be executed as the ordered suggested in the static code). The latter
orders cache block flushes such that clflush after the fence will not take effect before previous ones have completed.
The combination of one or more cache block flushes followed by a store fence is called a persistence barrier, which 
achieves the overall effect that store operations before the barrier will be written back to the NVM before
store operations after the barrier, and write backs before the barrier are guaranteed to complete before writes
after the barrier are executed.

Hippocrates limits its scope to three classes of common bugs that are found in applications. The first class is 
missing flushes, which is caused by programmers forgetting to put cache line flush primitives after data modification
operations, but before the memory fence primitive. 
The second class is missing fences, which is similar to the first class, i.e., a memory fence, rather than flush, is 
missing after flush primitives. 
The third class is missing both, which happens when both the flush and the fence primitives are not present.

The paper first proves that by inserting the missing primitives into the source code, these bugs can be fixed 
safely without introducing new bugs. 
In fact, we can prove that arbitrarily inserting flushes and fences into the source code will not incur new bugs.
Intuitively, this is true, since the cache hierarchy makes zero guarantee on whether a block will be evicted or not
unless a flush is explicitly issued, and the OoO core pipeline also makes zero guarantee on how instructions are 
ordered unless an explicit ordering is given by the specification. 
It is, therefore, always possible that some other events will cause the equivalence of flushes and store fences on 
the hierarchy and the core pipeline, respectively, without actually using these primitives.
The result dynamic execution trace, as a result, is always a subset of all possible dynamic traces of the original
program, implying that there will not be any program behavior that cannot be observed while executing the original
program.
