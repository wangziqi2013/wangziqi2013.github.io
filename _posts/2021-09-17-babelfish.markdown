---
layout: paper-summary
title:  "BabelFish: Fuse Address Translation for Containers"
date:   2021-09-17 23:52:00 -0500
categories: paper
paper_title: "BabelFish: Fuse Address Translation for Containers"
paper_link: https://dl.acm.org/doi/10.1109/ISCA45697.2020.00049
paper_keyword: Virtual Memory; Linux; Paging; MMU; Containers; BabelFish
paper_year: ISCA 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
--- 

This paper proposes BabelFish, a virtual memory optimization that aims at reducing duplicated TLB entries and page 
table entries. BabelFish is motived by the fact that containerized processes often share physical pages and the
corresponding address mappings. On current TLB architectures, these mappings will be cached by the TLB as distinct
entries, because of the ASID field for eliminating homonym or expensive TLB flushes on context switches.
BabelFish reduces the degree of redundancy in both TLB caching and page table entries in the main memory by allowing 
single TLB entries and single page table entries to be shared across processes, with probable exceptions tracked
by additional metadata structures. 

Container is a lightweight mechanism for isolating processes running in the same OS, which has drawn an increasing 
amount of interest in microservice and serverless due to its faster loading time compared with virtual machines.
Each containerized process may have its own namespaces and illusion of exclusive ownership to resources such as 
CPU, memory, and the file system. Processes in containers are, in fact, still Linux processes, and have their own 
address spaces with virtual-to-physical mapping. 
The paper observes that containerized processes typically have many identical VA to PA mappings and permission bits 
despite that they are actually in different address spaces. The paper identifies several factors that contribute to 
this observation.
First, in microservice and serverless architectures, the number of service instances are adjusted based on the dynamic 
load, and it is common that many instances of the same service are started to handle requests. All of the instances
share the same underlying binary and the libraries, which are also usually mapped to the same virtual address at each
process.
Second, the paper claims that container processes are created with the fork() system call, which produces a child 
process sharing the VA to PA mapping of the parent process in a Copy-on-Write (CoW) manner. Many pages will not
be CoW'ed, and remains being shared and read-only between the two processes, which are also at the same virtual
address and mapped to the same physical address.
Third, these processes can map certain shared files to the address using mmap() and MAP_SHARED flag, meaning that the
content of the file is mapped to the address space and is backed by the same physical pages. If mmap() picks the 
same virtual address for the mapping, all sharers will also observe the same VA to PA translation entries.
Lastly, cloud providers who is responsible for maintaining the containerized environments may also add their own
middleware for container management and pricing. The code and data of the middleware can also be shared by all 
processes.

BabelFish assumes a two-level TLB architecture, in which each entry consists of at least the VA, which is used as the
lookup key, the PA, a set of permission bits, and an ASID field to distinguish between the entries from different 
processes. The organization of the TLB is orthogonal to the topic. 
The paper also assumes Intel architecture's four-level, radix tree page table, and an MMU that could perform page walks.
A Page Walk Cache (PWC) may also be present to reduce main memory accesses from the page walk by caching the in-memory
translation entries from all levels.
