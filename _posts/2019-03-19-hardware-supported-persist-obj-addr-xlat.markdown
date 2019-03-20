---
layout: paper-summary
title:  "Hardware Supported Persistent Object Address Translation"
date:   2019-03-19 20:15:00 -0500
categories: paper
paper_title: "Hardware Supported Persistent Object Address Translation"
paper_link: https://dl.acm.org/citation.cfm?id=3123981
paper_keyword: NVM; mmap; Virtual Memory
paper_year: MICRO 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a memory access semantics for NVM by accelerating memory address translation on hardware. Designing
data structures for NVM is a difficult task, not only because the data structure itself will remain persistent even between 
reboots and process or even OS sessions, but also because the way that NVM is managed differs from the convention way
people use DRAM. The paper assumes an architecture where DRAM and NVM are both attached to the memory bus, and shares 
a single physical address space. The NVM, however, is not mapped by the OS by default to avoid applications writing 
NVM, causing data corruption that can persist reboots (i.e. is impossible to fix). Instead, NVM is only exposed to users
by calling mmap(), which in turn allocates a chunk of virtual address space, and maps these VAs to PAs on the NVM. In the 
following discussion we call a VA mapped tp NVM addresses a NVM region. Exposing address spaces via mmap() suffers relocation
problem: If NVM data structures were written in the same way as volatile data structures, which use the value of virtual 
addresses of the target object as pointers