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

**Questions**

1. Basic blocks that are dynamically recognized at early stages of execution may be split to smaller blocks later, due 
   to a jump to the middle. Such jumps cannot be detected before they are actually executed, since SimPoints is 
   execution-driven. Even worse, for branches whose target address is dynamically generated during execution, even
   full static analysis cannot find the destination.
   How does SimPoints handle such cases?
   One way is that when an known basic block is further divided into two by a jump instruction to the middle of the 
   block, one more element (the one on higher address) is pushed into the basic block list for all previous vectors.
   In addition, previous vectors are scanned. If they contain the old block (which now is also a new basic block),
   then the old block count is decremented, and the new block count is incremented.

2. If the size of simulated programs are reduced, the working set size may also be proportionally reduced, especially
   if the code segment contains loops that allocate and write heap memory. How does SimPoints evaluate such effect?
   Note that in the text it is indeed mentioned that by reducing the size of the program, the cache miss ratio 
   changes significantly sometimes. But the paper's conclusion is that this does not affect IPC.

3. Input changes may change the control flow of an application (although likely not significant changes), and thus 
   change the vectors. It may be necessary to recompute the vectors when the input changes.

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
and generate basic block vectors for each execution intervals. SimPoints divides the full execution into intervals of 
100M instructions, with one basic block vector associated with each interval. SimPoints then starts the application on 
its own execution-driven simulator. The simulator of SimPoints do not simulate architectural details. Instead, it only 
divides the control flow into basic blocks, and count the number of times each block is executed within the interval.
The initial run of SimPoints is, therefore, must faster than an architectural simulator, since for most the times the
simulator is merely executed on bare metal hardware without state computation.
As execution proceeds, new basic blocks are added, and existing basic blocks may also be splited into new ones.
Basic blocks are identified by the starting address of the first instruction, with a global hash table maintaining
all known basic block addresses for fast check.
New basic blocks are pushed to the end of the vector for all intervals when they are first discovered, such that at the
end of the simulation, each interval has a basic block vector of the same length, with each element being the number of
times the basic block is executed during that interval. These vectors will then be processed, compared and clustered 
in the following phases.

In the next phase, SimPoints reduces the dimention of basic block vectors before they are compared. Dimention reduction
is necessary, since according to the paper, both the time efficiency and clustering quality of vectors are worse with
high dimentional vectors. Dimension reduction is therefore applied to reduce the high dimention vectors, the length of
which is the total number of basic blocks. One of the most important properties of the dimention reduction algorithm
is that the distances between vectors should be preserved, although minor distortions are fine and inevitable.
The paper proposes that for basic block column vectors of size (N * 1), the dimention reduction is performed by left
multiplying the column vector with a matrix of size (M * N), in which M is the target dimension and M << N. 
Elements of the dimension reduction matrix are real numbers randomly selected from range [-1, 1]. Proof is also available
showing that length distortion after dimension reduction is within a bound. The paper suggests that M equal 15, and that
Euclidean distance be used for computing distance due to its better representation with lower dimensions.

After dimension reduction, the next step is to cluster the basic block vectors for all intervals. The number of clusters
can be external inputs given by the programmer, or be determined using BIC based on the "goodness". In the latter case,
cluster count from 1 to 10 are experimented, and the one with the best BIC score is selected.
The paper uses the well-known kmeans algorithm to compute clusters. Each cluster stands for one "representative" class
of intervals that is supposed to demonstrate similar properties in terms of architectural effects.

SimPoints offers two options for selecting the representative code segments. The first option is to only select a single
interval. In this case, the global centeroid across all vectors are computed, and the one with the clostest distance
to the centroid is selected. The second option is to have several segments. SimPoints will first select one vector from 
each cluster whose distance to the cluster's centroid is the smallest as candidate. Then SimPoints sorts these vectors
by the size of their clusters, and selects the top K where K is the intended number of code segments.

The actual architectural simulation is executed with the selected code segments as input arguments. The simulation is
fast forwarded to the first code segment by counting instructions (code segments are always 100M dynamic instruction in
size). After that full simulation begins until the instruction count reaches another 100M. If multiple code segments
are selected, the simulation is again fast forwarded to the next code segment, and performs full simulation. This process
is repeated until all code segments are simulated, after which the simulation could terminate.
