---
layout: paper-summary
title:  "Super-Scalar RAM-CPU Cache Compression"
date:   2020-09-23 23:49:00 -0500
categories: paper
paper_title: "Super-Scalar RAM-CPU Cache Compression"
paper_link: https://ieeexplore.ieee.org/document/1617427
paper_keyword: Compression; Database Compression
paper_year: ICDE 2006
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes a new database compression framework designed for new hardware platform. The paper identifies the 
importance of database compression as reducing I/O cost. There are, however, three drawbacks that prevent previous approaches
from fully taking advantage of the performance potential of hardware.
First, existing algorithms are not designed with the underlying hardware architecture and the newest hardware trend in
mind, resulting in sub-optimal execition on the processor. For example, the paper observes that modern (at the time of
writing) CPUs often execute instruction in a super-scalar manner, issuing several instructions to the same pipeline stage
at once, achieving an IPC higher than one.
Correspondingly, higher IPC on existing algorithms can be achieved, if the programmer and compiler can transform an 
algorithm to take advantage of data and control indepenent parallel instructions.
In addition, on pipelined microarchitecture, when data or control hazards occur, the pipeline has to be stalled until
the hazard is resolved, hurting performance. This implies that the algorithm should refrain from using branching structures,
while performing as many parallel loads as possible.
Second, conventional delta- or dictionary-based compression algorithms may not achieve optimal compression ratio in the
presense of outliers. Outliers can increase the number bits required to encode a tuple, but contribute to only a 
small fraction of total data storage. By not compressing outliers and always storing them in uncompressed form, 
the value range of compressed value can be greatly reduced, resulting in less bits per tuple and higher compression ratio.
Lastly, existing database compression schemes put the compression boundary between disk and memory page buffer, meaning 
that pages are stored in decompressed form once brought into the memory, enabling fast random access. 
This architecture has a few disadvantages. First, this causes significant write amplification, as the compressed page
is first read via I/O, and then decompressed in the memory. Second, this also damands higher storage since uncompressed
pages are larger than compressed pages.


The paper addresses the above challenges with the following techniques. First, the algorithm proposed in this paper
mainly consists of small loops without branching. Compilers may easily recognize the pattern, and expand the loop
using loop expansion or loop pipelining. The former technique simply expands several iterations of the loop into the 
loop body, while the latter further re-arranges operations from different iterations to overlap the execution of 
multiple iterations to increase the number of parallel operations. For example, if a single iteration consists of a few
loads, some computation, and then stores, these loads and stores can be "pipelined", i.e., the load operations of the next
few iterations can be promoted to be executed together with the loads in the current iteration, if the memory
architecture can sustain the bandwidth parallelism.
