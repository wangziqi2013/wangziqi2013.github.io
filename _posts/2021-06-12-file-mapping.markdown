---
layout: paper-summary
title:  "Rethinking File Mapping for Persistent Memory"
date:   2021-06-12 16:33:00 -0500
categories: paper
paper_title: "Rethinking File Mapping for Persistent Memory"
paper_link: https://www.usenix.org/system/files/fast21-neal.pdf
paper_keyword: NVM; File System; Cuckoo Hashing
paper_year: FAST 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents two low-cost file mapping designs optimized for NVM. The paper observes that, despite the 
fact that file mapping accesses may constitute up to 70% of total I/Os in file accessing, little attention has been
paid to optimize this matter for file systems specifically designed for NVM.
The performance characteristics of NVM also makes it worth thinking about redesigning the file mapping structure.
For example, NVM's byte-addressability enables file systems to implement data structures that require fine-grained
metadata and data accesses, such as hash tables, while conventional block-based file systems typically adopt designs
that are optimized for block accesses, such as trees with high fan-outs. 

File mapping is an abstract function that translates a logical block offset in a file into a physical block
number on the device. This simplifies file system's logical view of files, as each file can be separately considered
as a consecutive range of blocks starting from zero (sparse files are supported by not mapping certain blocks in the
middle of the file, but the abstraction of a consecutive range persists to make sense).
The file mapping function, therefore, is defined as a function that, given the file's identify (usually represented
by its inode number, as this paper assumes) and the logical block number, output a physical block number where the 
data that corresponds to the logical block can be found. 

The paper notices that, generally speaking, two types of file mapping have been implemented by previous proposals.
The first type is local mapping, where each file has its own file mapping structure, and these structure instances
are physically disjoint objects, which are typically found in the inodes. 
