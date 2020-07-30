---
layout: paper-summary
title:  "Automatically Characterizing Large Scale Program Behavior"
date:   2020-07-29 18:02:00 -0500
categories: paper
paper_title: "Automatically Characterizing Large Scale Program Behavior"
paper_link: https://dl.acm.org/doi/10.1145/605397.605403
paper_keyword: Debugging; SimPoints
paper_year: ASPLOS 2002
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Note: Source code of SimPoints is available, which contains the full implementation, and should serve as the ultimate
source of reference. This paper summary is merely based on what was written on the published paper, not on what is in
the code repo (things might have changed, or the author did not give full clarification to certain details)**

**Lowlight:**

1. Basic blocks that are dynamically recognized at early stages of execution may be split to smaller blocks later, due 
   to a jump to the middle. Such jumps cannot be detected before they are actually executed, since SimPoints is 
   execution-driven. Even worse, for branches whose target address is dynamically generated during execution, even
   full static analysis cannot find the destination.
   How does SimPoints handle such cases?

2. If the size of simulated programs are reduced, the working set size may also be proportionally reduced, especially
   if the code segment contains loops that allocate and write heap memory. How does SimPoints evaluate such effect?
   Note that in the text it is indeed mentioned that by reducing the size of the program, the cache miss ratio 
   changes significantly sometimes. But the paper's conclusion is that this does not affect IPC.

This paper introduces SimPoints, a simulation tool for accelerating architecture simulation using basic block vectors.
SimPoints aims at solving the problem of architectural simulation, especially cycle-accurate simulation, taking too much 
time to finish on typical full-scale workloads. 
Previous works attempting to achieve the same goal typically employ manual tailoring of source code or inputs, the usage
of checkpoints and fast forwarding, and statistics methods with profiling. 
These approcahes, however, either uses architectural metrics such as IPC and cache miss ratios, or heavily rely on the 
simulated platform itself to provide feedback. One direct consequence of these methods is that they have to be re-run
when the simulated platform changes, and when input changes. 

SimPoints, on the contrary, locates these code segments independent from architectural details by leveraging the fact 
that basic blocks are the basic unit of control flow, which must be executed from the beginning to the end. 
Given the same start system state (including non-deterministic states), the end state after executing the 
basic block will always be the same regardless of the context of the basic block and the architectural details of the 
simulation. SimPoints then abstracts away the internals of basic blocks, and treats them as the fundamental unit of execution.
Recall that the goal of SimPoints is to find one or more small code segments that are representative of the full execution.
The paper argues that if the basic block instances included in the code segments are similar to the total basic blocks
in the full execution, then these code segments can be used as an approximation of the simulated application.

Based on the above observation, the problem of finding representative code segments is reduced to finding one or more 
execution intervals in which the basic block instances that are executed are similar to those of the full execution.
Instead of bookkeeping every basic block within an interval, and comparing them with each other to find similarities,
which is both inefficient and unnecessary, the paper proposes that basic blocks within an interval be represented as 
a basic block vector, discarding information such as the order of execution.
Using vectors has two obvious advantages. First, similaries between vectors and clustering of vectors are both well-known
problem, and there exists simple solutions for them. Second, vectors are easier to store and access, compared with the
actual control flow graph of the interval.

We next describe the details of SimPoints as follows. The first step of SimPoints is to collect basic block information
and generate basic block vectors for each execution intervals. Overall speaking, SimPoints divides the full execution
into intervals of 100M instructions, with one basic block vector associated with each interval. SimPoints then starts
the application on its own execution-driven simulator. 
