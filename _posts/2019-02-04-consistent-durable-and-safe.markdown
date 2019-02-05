---
layout: paper-summary
title:  "Consistent, Durable, and Safe Memory Management for Byte-Addressable Non-Volatile Main Memory"
date:   2019-02-04 18:20:00 -0500
categories: paper
paper_title: "Consistent, Durable, and Safe Memory Management for Byte-Addressable Non-Volatile Main Memory"
paper_link: https://dl.acm.org/citation.cfm?doid=2524211.2524216
paper_keyword: NVM; Malloc; B+Tree
paper_year: TRIOS 2013
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---  

This paper aims at building a flexible and versatile library for applications to work with the incoming NVM devices.
NVM, due to its special performance and physical characteristics, requires new methodology for tasks such as 
storage management, access permissions, consistency model, and so on. Compared with disks, NVM devices are directly
connected to the memory bus, and hence can be accessed by ordinary load and store instructions, at cache-line granularity.
Accesses to NVM are directly backed by the processor cache, which has hardware controlled cache management policy.
In contrast, disks are mostly accessed with block transfers, which is backed by an operating system controlled 
software buffer cache. Compared with DRAM, NVM features slightly slower reads and much slower writes. In addition, 
execssive writes to the same physical location may cause NVM to wear out and become incapable to record data reliably. 
To avoid this from happening, most NVM devices are equipped with firmware that maintains an internal mapping, which maps 
write operations on the same logical address to different locations, minimizing wear. As a result, algorithm for NVM 
should be designed in such a way that data overwriting is minimum.

Existing libraries and system calls such as malloc, mprotect, etc, are not designed to fit into the NVM paradigm. To
be specific, we assume that NVM is installed into one of the memory slots of the host machine, and can be addressed
as part of the physical address space. The operating system maintains information about the NVM address space. Users
request a chunk of memory mapped to NVM using mmap() system call. The returned virtual address can then be used to
directly operate on the NVM. NVM memory regions are by default cachable to improve read and write throughput. Memory
protection on NVM area are achieved by existing virtual memory protection mechanism. Under these assumptions, libraries
running on NVM should satisfy the following requirements. First, they should reduce memory overwrite as much as possible 
to protect the NVM device from wearing out too quickly. On existing library implementations such as glibc malloc, however, 
the opposite will happen. To improve locality of reference, glibc internally divide memory chunks into different 
size classes, and each size class is maintained as a linked list with pointers stored within the memory chunk. Memory
chunks are poped from and pushed into the linked list in LIFO order for good locality, because chunks that are freed
recently are more likely to be allocated in the future. In addition, on every memory allocation and free, the pointer
and metadata fields in the header and footer will be modified, which increases the probability that certain addresses are 
more prone to wearing.