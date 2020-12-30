---
layout: paper-summary
title:  "Elastic Cuckoo Hashing Tables: Rethinking Virtual Memory Translation for Parallelism"
date:   2020-12-29 18:12:00 -0500
categories: paper
paper_title: "Elastic Cuckoo Hashing Tables: Rethinking Virtual Memory Translation for Parallelism"
paper_link: https://dl.acm.org/doi/10.1145/3373376.3378493
paper_keyword: Virtual Memory; Page Table; Cuckoo Hashing
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Elastic Cuckoo Hashing Table (ECHT) and a new virtual memory address mapping framework for more
efficient page walks and translation caching.
The paper begins by identifying a few limitations of current page table design and research proposals. 
The current design, using radix tree as the table and bit slices of the address to index each level of the tree,
suffers from squential read problem, since the next level in the radix tree can only be determined after the 
previous level is read from the memory.
In addition, many modern implementations add page walk caches to further accelerate page table walk. The intermediate 
levels of the radix tree will consume cache storage while not contributing to translation, if lower level entries
are also cached.

To overcome the extra indirection levels of a radix tree, some prior proposals suggest that hash tables should be used 
for fast, low latency search. Hash tables, however, are also not perfect candidates for this purpose, due to several
problems. First, hash conflicts can occur, especially when the table is densely populated. Common conflict resolution
approaches, such as open addressing and chaining, will not work well for a hardware page walker, since they also
incur extra levels of indirection or sequential memory access, which can even be slower than radix trees.
Second, hash tables require constant resizing when being inserted into. The resizing operation either needs a long 
latency full-table copy and rehashing, or can be done lazily by allowing both the old and new table to be present, 
at the cost of increased number of memory accesses and storage consumption.
Third, the paper also claims that none of the prior hash table proposals support multiple page sizes in the same table,
neither can they support process-private page tables, complicating common tasks such as address iteration for a 
certain process and huge pages.
