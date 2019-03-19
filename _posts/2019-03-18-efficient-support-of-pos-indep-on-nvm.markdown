---
layout: paper-summary
title:  "Efficient Support of Position Independence on Non-Volatile Memory"
date:   2019-03-18 22:52:00 -0500
categories: paper
paper_title: "Efficient Support of Position Independence on Non-Volatile Memory"
paper_link: https://dl.acm.org/citation.cfm?id=3124543
paper_keyword: NVM; mmap; Virtual Memory
paper_year: MICRO 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes an efficient pointer representation scheme to be used in NVM as a replacement for raw volatile pointers. 
Using raw volatile pointers for NVM memory regions is risky, because almost all currently proposed methods for accessing
NVM is through Operating System's mmap() system call. On calling mmap(), the OS finds a chunk of virtual pages in the calling 
process's address space, and then assigns physial NVM pages to the allocated vierual addresses. On future calls to mmap(),
either by the same process or a different process, however, there is no guarantee that the two mmap() calls will put the 
NVM region on the same virtual address. Imagine the case where raw pointers are used within a persistent data structure, 
and the persistent object is copied to another machine. When the user open this object via mmap(), the base address 
of the mapped NVM region might change, which makes pointers in the data structure invalid, because the address they point 
to may be no longer valid. In addition, cross-region reference (i.e. pointers from one mmap'ed region pointing to another
mmap'ed region) will not work if the target region is relocated or does not exist. All these properties of NVM pointers 
motivate the development of position independent pointers.

Two prior designs are discussed in the paper: fat pointers and based pointer. Fat pointer is a struct consisting of two fields:
Region ID and Region offset. The region ID field identifies which NVM region the pointer is based on. The base address is 
implicitly defined as a region property, and is maintained by the OS. The offset field specifies a byte within the region. 
For every memory access using the fat pointer, a virtual address must be generated and provided to the memory instruction.
To achieve this, the NVM library maintains a hash table mapping region IDs to region properties. When a new region is mapped by the OS, the NVM library adds a