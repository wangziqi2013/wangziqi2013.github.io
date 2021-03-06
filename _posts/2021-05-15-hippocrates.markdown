---
layout: paper-summary
title:  "Hippocrates: Healing Persistent Memory Bugs without Doing Any Harm"
date:   2021-05-15 21:43:00 -0500
categories: paper
paper_title: "Hippocrates: Healing Persistent Memory Bugs without Doing Any Harm"
paper_link: https://dl.acm.org/doi/10.1145/3445814.3446694
paper_keyword: NVM; Bug Finding; Hippocrates
paper_year: ASPLOS 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Comment:**

1. When to apply inter-procedure fixes? Is there some clear criteria? The paper did not mention when to apply
   this type of fix. The bug report from third party utilities only identifies missing primitives, as I understand.

2. Not all problems can be attributed to missing primitives. Some might be complicated bugs involving non-persistent 
   logic. Others might be due to control flows, etc. 
   Is is possible for the tool to handle these cases?

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
The resulting dynamic execution trace, as a result, is always a subset of all possible dynamic traces of the original
program, implying that there will not be any program behavior that cannot be observed while executing the original
program.

The paper also recognizes two types of fixes that can be applied. The first type is intra-procedure fix, which is 
applied right on the spot where the primitive is missing in the same function. This approach is simple, but may result
in inefficient code, if the procedure is called for both persistent and non-persistent memory objects.
For example, library functions cannot be fixed this way (and we often do not have access to their sources),
such as memcpy() or memset(), since these functions are widely used for all types of objects.
If primitives are inserted into these functions, then unnecessary flushes and/or fences will be executed
even when they are called on non-persistent objects, degrading performance.

The paper therefore proposes a second type fix, called inter-procedure fix, in which the fence primitives
are inserted in one of the caller functions of the procedure. 
Note that Hippocrates are not allowed to modify existing primitives, as the correctness proof assumes that no existing
primitives are changed.
It can, however, generate a "persistent" copy of these functions by duplicating the existing functions (called 
a persistent subprogram, which includes all functions in the call chain), assigning them different names, and 
then inserting a flush primitive after every persistent memory write within the subprogram. 
Invocations to the original version of the subprogram using persistent objects and are identified as "buggy" 
are then replaced with the 
A single fence primitive is then inserted after the call site to the persistent subprogram.
Recall that inserting new primitives will not introduce new bugs, this preserves the correctness of the program.
Furthermore, calling the persistent subprogram will guarantee that all writes performed within the function have 
been persisted, which will guarantee to fix any missing primitive issue.
(**OK, I did not quite get how it works, so this is the best I can do**).

Hippocrates takes the output of third party bug-finding tools, which contains a dynamic trace of persistent memory 
accesses, the stack traces when these accesses happens, and the precise location of a buggy access.
It relies on LLVM framework, and the fixes are implemented as an extra LLVM pass.
