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

