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
The benefit of local mapping is its locality of access and high degree of parallelism.
The former is a result of having dedicated structure per-file, while the latter is because file mapping
structures can be locked independently from each other without causing global bottlenecks.
The disadvantage, however, is that local mapping may incur fragmentation and hence harm locality, as the mapping  
structure needs to be resized as the file size changes. Resizing operation typically requires relocating some 
structures to a larger block, or the usage of multiple levels of indirection. 
Both will decrease locality and increase fragmentation.

The second type is global mapping, in which all files are mapped by the same global structure. The global mapping 
takes both the inode number of the file as well as the logical block number, and outputs the physical block number.
The biggest advantage of global mapping is that the structure can be statically allocated, and does not require 
resizing, as the maximum number of mapping entries is known in advance: The maximum number of possible mappings
will not exceed the number of available physical blocks. 
This reduces fragmentation, since the entire structure can just be pre-allocated in a large continuous area at
file system initialization time.
The drawback of having a global mapping structure, however, is that locality of access can be lower, since the
translation entries of a file is randomly distributed across the entire structure, unlike in local mappings where
these entries will only reside in a much smaller structure.
Besides, the degree of parallelism may also become a concern, since it is unclear how fine-grained 
synchronization between processes are performed.
The paper points out, however, that the synchronization overhead can be addressed with the following two observations.
First, some data structures, such as hash tables, can be conveniently locked on a per-bucket basis, as operations in one
bucket will not interfere with operations on another one.
Second, the mapping structure will not be updated unless the size of the file is changed (e.g., appending, truncation or
deletion). This indicates that file reads and writes will mostly only read the file mapping structure, while only a 
few of them may require exclusive access. These operations, therefore, can be easily synchronized
with reader-writer locks without having to sacrifice too much parallelism, as most operations will just be concurrent
reads to the structure.

The paper then gives a review of two existing local file mapping approaches: extend tree and radix tree. 
Extend tree is a variant of B+Tree, in which inner and leaf nodes use extents, rather than exact key values, 
for key comparison. An extent is just a consecutive range of blocks allocated to file data in both logical
and physical block address spaces. Due to the fact that they are consecutive, extents can be encoded 
efficiently using tuples of the form (start logical block, start physical block, size), rather than with 
per-block mapping, reducing the number of mapping entries. 
It is extremely helpful when the file is allocated mostly with large extents and is accessed sequentially, as block 
mapping can easily be computed by just performing a few extent accesses.
In addition, sequential accesses can also be accelerated with cursor, which is just a pointer to the leaf level of 
extent trees that supports fast iteration over the file mapping without having to traverse down the tree from the root 
level. The cursor is preserved across several file system calls as a token for representing the last accessed location.

Radix tree is another form of tree indices. The difference between radix tree and extent tree is that the radix tree
always performs per-block mapping, and therefore, is less space efficient. Besides, access locality can also be worse 
for an unoptimized radix tree, as its height is only a function of key size (i.e., number of bits in logical block 
number), which is most likely constant for a file system.

The paper then proposes two global file mapping schemes. The first one is essentially a global cuckoo hash table
which maps (inode number, logical block number) to an extent of the form (physical block number, size). 
The cuckoo hash table is allocated statically as an array, the size of which can be determined at file system
initialization time. Two unspecified hash functions are used, which bounds the number of memory accesses for
read to two. Insert and read algorithms are just standard cuckoo hashing, and we do not cover them here.

One of the most prominent features of the cuckoo hash table is that it uses hybrid extent and per-block mapping.
On one hand, the cuckoo hash table has one mapping entry per block, allowing random access within the file using
any logical block number for table query. On the other hand, the file system still attempts to allocate data blocks
in extents, and for each mapping entry, the size of the extent that the physical block lies in is maintained. 
In other words, for extents with several blocks, each of the block will have a mapping entry, and in each of the entry,
the information about the extent is stored.
This feature enables fast sequential accesses and the implementation of cursors, as the file system can still maintain
a cursor across file operations that points to the last accessed mapping entry, in which the extent is stored.
Extent information should also be updated when the extend changes (e.g., when it shrinks as a result of file 
truncation). This is performed by iterating over all mapping entries for blocks in the extent, and updates 
extent information in each of them.