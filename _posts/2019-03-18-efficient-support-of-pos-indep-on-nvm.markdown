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
process's address space, and then assigns physial NVM pages to the allocated vierual addresses. On the next call to mmap(),
either by the same process or a different process, however, there is no guarantee that the two mmap() calls will put the 
NVM region on the same virtual addresses. Imagine that if raw pointers are used within a persistent data structure, and the 
data structure is closed 