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
address to host physical address. On TLB misses, the hardware must perform a 2-D page table walk, which requires consulting the 
host page table for every guest physical address. With NPT, the guest OS is free to modify the guest page table without 
notifying the VMM.

Both shadow page table and NPT achieve memory virtualization. The extra overhead, however, come from different sources. For 
shadow page table, translation by performing a page walk requires at most four memory accesses (assuming 64-bit architecture).
On the other hand, when the guest OS changes the mapping, the VM must trap into VMM, and the VMM updates the shadow page table.
Trapping into VMM is an expensive operation, and we hope this would happen as infrequent as possible. For NPT, a 2-D page walk
can take up to 24 memory accesses: For each guest physical address, we need four accesses to the host page table, plus one access
to the guest page table to access the entry. For the final guest physical address, we then need an extra four accesses to the 
host page table to translate it into host physical address. As mentioned in the previous paragraph, altering an entry in the 
guest page table is relatively faster, as the VMM is not involved in this process.

In this paper, the author proposes Agile Paging, a solution that integrates shadow page table and NPT into a unified 
translation framework. Agile paging aims at reducing the extra overhead of updating when guest OS frequently updates 
a page by allowing that page(s) to be translated by NPT, while maintaining the fast translation scheme using shadow page 
table for the rest of the pages. In the next paragraph we explain how this goal is achieved.

To support agile paging, the hardware adds another page table register, which holds the host physical address of the 
shadow page table. Three page table registers are needed in a translation: one register for shadow page table; the other 
two are guest page table register and host page table register for NPT. All three tables can be cached by the TLB. 
The hardware page walker state machine is modified, such that translation always begins at shadow page table. We add one 
bit to each entry of the shadow page table to indicate whether the translation should switch to NPT in the next level. 
If the bit is clear, then the page walker treats the address stored in the entry as the next level shadow page table 
(or page frame number, if on the last level). If the bit is set, the page walker treats the adderess as the physical address
to the next level of the guest page table as in NPT scheme. The translation then continues as a 2-D page walk.

The hybrid shadow and nested page table design gives the VMM an opportunity to assign different translation policies to
different address areas. For areas that rarely change and are relatively stable, the translation takes place using
shadow page table for speed. For areas that undergo frequent modification, to avoid trapping into the VMM on every
write, the translation scheme is assigned to use NPT. Overall speaking, fewer traps and less memory accesses can improve the 
efficiency of memory virtualization.