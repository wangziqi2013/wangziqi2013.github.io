---
layout: paper-summary
title:  "Tag Tables"
date:   2019-09-01 20:03:00 -0500
categories: paper
paper_title: "Tag Tables"
paper_link: https://ieeexplore.ieee.org/document/7056059
paper_keyword: L4 Cache; DRAM Cache; Tag Table; Page Table
paper_year: MICRO 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes tag table, a tag encoding technique for tag store of large DRAM L4 cache. Conventional DRAM caches,
such as L-H cache and Alloy Cache, store cache tags of blocks within the DRAM, usually at the same row as block data to
achieve lower latency, leveraging the row buffer to avoid activating two different rows for one access. This approach,
however, still requires one row activation operation, which is relatively quite expensive compared with SRAM read and 
DRAM column read, which is on the critical path of cache query.

Since tag lookup is an indispensable part of every cache query, regardless of the result, this paper aims at optimizing
the tag lookup overhead by storing the tags in an on-chip SRAM structure. The problem with SRAM tag store, however, is 
that for a DRAM cache of several GBs in size, the tag store will take around 10% of the data storage (assuming 6 byte tag
and metadata such as dirty bits, coherence states, etc., we compute the ratio between tag and data as 6 / 64 = 9.37%).
In the conventional set-associative scheme, in which every data slot in the DRAM cache has a corresponding tag slot
in the tag array, storing these tags will cost hundreds MBs on the chip, which is most likely not practical nowadays
and in the near future considering several factors such as cost, latency, energy, and area.

The paper seeks to reduce the amount of storage required to store all tags on-chip by adopting a mapping structure 
similar to a page table, enabling adaptive tag storage policies. This solution is based on the observation that
conventional tag array approach of maintaning tags within a set is similar to inverted page table (IPT). In the realm of 
virtual memory, an inverted page table reserves an array of virtual addresses, the size of which equals the number of 
physical pages. Entry i of the inverted page table stores the tag of the virtual address that is mapped to the physical
frame. When translating a virtual address, the table is associatively searched to locate the physical frame number by 
comparing every virtual address against the requested address. Given that the physical address space is often several GBs
in size (which is far more larger than a set in the cache), this process is typically accelerated by hashing the virtual
address to a certain location in the IPT, and then start linear probing from that point. As discussed above, the size of 
an IPT is bounded by the number of physical pages (or cache blocks in a set compared) rather than the number of virtual
pages. In the case where the virtual address space is larger than the physical address space, such as virtual memory, the 
IPT has an obvious advantage over a direct-mapped page table (an array of physical frame numbers, the size of which equals 
the number of virtual pages).

On the other hand, a page table can be optimized to consume less storage while still using forward mapping 
(i.e. mapping VA to PA). For example, multi-leveled page table, implemented as radix trees, allows flexible 
allocation of mapping table storage in three aspects. First, compared with a direct-mapped array, storage does not need 
to be consecutive, since tree nodes are linked together using pointers. Second, if a subtree is empty, the upper level 
parent can just store an empty pointer in the corresponding field. The tree walker is able to infer this case when seeing 
an empty pointer. The last, and the most important point is that, if a middle-level subtree P only has one leaf-level entry 
E as its only decendant, i.e. there is a path from P to E and no other nodes in the tree can be reached except the nodes on the 
path, the path can be compressed by storing the leaf node E within node P. 

The design of tag table borrows from multi-leveled page table, such that physical addresses are mapped to the location
of data block in the DRAM cache. The DRAM cache is organized as a set-associative cache with extremely high associativity.
The paper assumes 4KB DRAM row, which can support at most 64 cache blocks. Metadata such as dirty bits and coherence states
are stored in the mapping table for fast access and update. The paper also assumes 48-bit physical addresses. When translating 
an address A, we form the row selection index using bit 12 to bit 29 of the address. This index is sent to the DRAM controller
to activate the row. 

The leaf
entry is an array of direct-mapped 