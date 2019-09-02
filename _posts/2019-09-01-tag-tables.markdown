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
to activate the row. In the meantime, a four-level page walk is performed to map the higher bits of the address into 
a leaf level entry, the content of which will be explained later. The four-level page walk uses bit 12 to 20, bit 21 to 29, 
bit 30 to 38 and bit 39 to 47 to form the index to level 1, 2, 3 and 4 nodes of the radix tree, respectively. We assume that
the page walk always reaches a leaf node at level four, and discuss the case of the path compression later. Note that this
mapping scheme differs from the x86 page table in two aspects. First, indices are formed from middle bits to higher bits
of the address, rather than starting from the highest bits as in x86-64 page table. This is consistent with how the address
is used: We use middle bits as the row selection index, which will also be used as the indices for first two levels of the 
tag table walk. This guarantees that the subtree we reach after two levels of table walk will cover only the row being 
activated. This property is extremely helpful if information on the row is to be collected, since the tag table scan
is localized to only the subtree describing the mapping of the row. The paper calls the subtree as "page roots".
In addition, since memory allocation on a typical machine is performed at 4KB granularity, which is also the size 
of a tree node in the tag table (9 bits can address 512 entries. Assuming each entry is 8 byte pointer, this sums up to
exactly 4KB). To avoid creating too many "sparse" nodes in which the majority of entries are empty (indicating no
subtree), we would like to use the high entropy bits at the first few levels, such that nodes in these levels are mostly
populated to increase cache performance.

In order for the tag table walk to proceed in parallel with row activation, the paper suggests that the tag table be made
addressable in the conventional DRAM and cachable by the LLC. The tag table walk will most likely hit the LLC, the latency 
which is much smaller than a row activation.

After reaching the leaf entry, the tag table walker performs the last step of mapping using the remaining 6 bits from
the address, bit 6 to 11, which encodes the offset of the cache block in the physical page. The leaf entry is simply
an array of 6 bit integers that maps the source offset to the destination offset in the DRAM row. A leaf page in this 
case will take at least 48 bytes. To further reduce memory consumption and the tag walk complexity, the paper proposes
compressed leaf entry. A compressed leaf entry represents a consecutive range of blocks mapped from the physical page
to the DRAM row, and the compressed leaf entry can be linked to level 2 or level 3 nodes. The compressed leaf entry consists
of two parts. The first part is a tag field, which stores either 9 bits or 18 bits tag, which is (are) the index that
should have been used to address level 3 and level 4 nodes. The second part is a range descriptor, which itself consists
of four fields: A page offset field (6 bits) to specify the beginning of the range in the physical page; A length (6 bits)
to describe the number of blocks in the range; A row offset (6 bits) to specify the beginning of the range in the DRAM row,
and a dirty bit to indicate whether any of these blocks are dirty. Four descriptors can be stored within one compressed 
leaf node, which sums up to 12 bytes. Such a leaf node can describe the same row layout as long as there are less than 
five consecutive regions in a physical page, saving both storage and lookup latency.

On insertion of a new block into a compressed leaf entry, the tag walker should ensure that the number of regions do not
exceed four, because otherwise the leaf entry has to be expanded to the full-sized entry, and in the case of level-3 or -4
leaf nodes, be assigned new internal nodes as parents. To achieve this, the paper suggests that the tag walker map blocks
to consecutive locations in the DRAM cache as much as possible. Even in the case of an expansion, however, the insertion
operation still occurs off the critical path as a background task. 
