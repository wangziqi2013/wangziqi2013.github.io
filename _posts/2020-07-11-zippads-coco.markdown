---
layout: paper-summary
title:  "Compress Object, Not Cache Lines: An Object-Based Compressed Memory Hierarchy"
date:   2020-07-11 01:19:00 -0500
categories: paper
paper_title: "Compress Object, Not Cache Lines: An Object-Based Compressed Memory Hierarchy"
paper_link: https://dl.acm.org/doi/10.1145/3297858.3304006
paper_keyword: Cache; Compression; Object; Hotpads; Zippads; COCO
paper_year: ASPLOS 2019
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Zippads and COCO, a compression framework built on an object-based memory hierarchy with object-aware 
compression optimization. The paper begins by identifying a few problems with conventional memory and cache compression 
architectures when applied to object-oriented language programs.
First, these algorithms are often designed and evaluated with SPEC benchmark, which mostly consists of scientific computation 
workloads. These workloads constantly use large arrays of simple data types such as integers, floating point numbers, or 
pointers. Classical compression algorithms work well on these data types, since they only consider redundancy in a small
range in the address space, such as one or a few cache lines. 