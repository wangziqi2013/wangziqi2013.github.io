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
range in the address space, such as one or a few cache lines. With object oriented languages, most of the working sets
consist of objects, which are laid out in the address space with fields of the same object stored in adjacent addresses. 
Conventional algorithms perform less efficiently on objects, since distinct object fields are often not of the same type, 
and have less dynamic value locality compared with arrays of homogeneous data.
Second, most compressed memory architectures require a mapping structure or some implicit rules for locating the address
of a compressed line, since such lines are not always stored in their uncompressed locations. In the former case, the 
extra storage and memory traffic of the mapping structure may just offset the benefits of main memory compression.
In the latter case, the mapping rule must be statically determined, which tends to make use of memory storage less
efficiently, since a compressed block cannot be placed arbitrarily in the address space.
Lastly, conventional compressed cache designs employ the combination of an over-provisioned tag array and segmented data
array for mapping variably sized compressed blocks in the cache. This organization creates two problems. The first
problem is that blocks are most likely only stored at segment boundaries, at a certain order, with the possibility of 
both internal and external fragmentation. The second problem is that on each cache lookup, more tag addresses and metadata 
have to be read and compared in parallel, consuming more power with a potentially large access latency, which can negatively
impact performance as well.