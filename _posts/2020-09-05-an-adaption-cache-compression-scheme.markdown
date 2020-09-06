---
layout: paper-summary
title:  "An Adaptive Memory Compression Scheme for Memory Traffic Minimization in Processor-Based Systems"
date:   2020-09-05 01:58:00 -0500
categories: paper
paper_title: "An Adaptive Memory Compression Scheme for Memory Traffic Minimization in Processor-Based Systems"
paper_link: https://ieeexplore.ieee.org/abstract/document/1010595
paper_keyword: Compression; Adaptive Compression; Dictionary Encoding
paper_year: ISCAS 2002
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents an adpative memory compression scheme to reduce bandwidth usage. The paper points out that prior 
compression schemes, at the point of writing, only uses a fixed dictionary, which is obtained from static profiling, for 
compressing symbols between the LLC and the main memory. This scheme works well for embedded systems, as these systems
typically only execute a limited set of programs for fixed functions. When it comes to general purpose processors,
this will not work well, given a braoder range of programs that will be executed. 

The paper, therefore, proposes a simple compression scheme with adaptive dictionary. The basic architecture is simple:
A compression and decompression module sit between the LLC and the main memory. A metadata store maintains metadata
fields such as compressed size, compressed store addresses, etc., as we will see later. 