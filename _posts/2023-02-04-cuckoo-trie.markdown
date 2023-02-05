---
layout: paper-summary
title:  "Cuckoo Trie: Exploiting Memory-Level Parallelism for Efficient DRAM Indexing"
date:   2023-02-04 19:23:00 -0500
categories: paper
paper_title: "Cuckoo Trie: Exploiting Memory-Level Parallelism for Efficient DRAM Indexing"
paper_link: https://dl.acm.org/doi/10.1145/3477132.3483551
paper_keyword: B+Tree; Trie; Cuckoo Hashing; Cuckoo Trie
paper_year: SOSP 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents Cuckoo Trie, a hashed radix tree (trie) representation that utilizes memory-level parallelism 
for more efficient lookups. The paper is motivated by the low memory-level parallelism of conventional pointer-based 
ordered indexing structures, such as B+Trees and radix trees. The paper focuses on radix trees and addresses 
the problem with a hashed representation of the radix tree nodes, such that nodes on the tree traversal path can be 
prefetched using key prefixes. Compared with conventional pointer-based radix tree implementations that serialize 
the memory accesses at each level, Cuckoo Trie demonstrates higher operation throughput on certain workloads.

The paper begins by observing that modern out-of-order hardware has a high degree of memory-level parallelism. In
particular, the hardware can execute non-dependent memory instruction out-of-order and tolerate multiple cache misses
until the hardware resources such as MSHRs are saturated. However, the capability of performing memory operations in 
parallel is often under-utilized by conventional implementations of radix trees, as in these
implementations, the next level of tree traversal can only be obtained after the parent level is fetched from the 
memory hierarchy. To make things worse, on modern big-data workloads, the amount of working set data will likely
exceed the size of the cache hierarchy, meaning that the memory accesses will suffer cache misses on all levels
and be satisfied by the main memory serially. Consequently, the overall performance of these implementations will 
degrade as the working set is becoming larger due to the lack of memory-level parallelism.


