---
layout: paper-summary
title:  "Agile Paging: Exceeding the Best of Nested and Shadow Paging"
date:   2018-05-18 21:05:00 -0500
categories: paper
paper_title: "Agile Paging: Exceeding the Best of Nested and Shadow Paging"
paper_link: https://ieeexplore.ieee.org/document/7551434/
paper_keyword: Agile Paging; Nested Paging; Shadow Page Table
paper_year: 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Hardware supported memory virtualization is crucial to the performance of a virtual environment. Two techniques
are applicable for solving memory virtualization problem. Shadow paging, which requires no extra hardware support
besides normal paging and protection machanism, stores a "shadow page table" along with the page table of the guest
OS. The hardware uses the shadow page table to perform translation. In order to maintain the consistenct between guest OS's 
view of the memory and the actual mapping implemented by the shadow page table, the host OS must compute the composition of 
the guest page table and its own page table, and store the mapping in the shadow page table. During a context switch, whenever
the current page table pointer is switched, the guest OS will trap into the VMM, and VMM finds the corresponding shadow
page table before setting it as the page table that hardware uses. In case that the guest OS modifies the mapping in the guest 
page table, the entire guest OS page table is write protected by the VMM. Any write operation to the guest OS page table will 
then trap into VMM. The VMM is responsible for reflecting the change to the shadow page table. 

Nested page table (NPT) replaces shadow page table on platforms that support Intel VT-x. With nested page table, the guest OS
composes its own page table without intervention from the VMM. The VMM has a second set of page table that maps guest physical
address to host physical address. 