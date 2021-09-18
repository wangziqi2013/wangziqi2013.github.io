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

