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
In addition, 