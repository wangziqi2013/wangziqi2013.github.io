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
NVM, due to its special performance and physical characteristics, requires a new set of rules for tasks such as 
storage management, access permissions, consistency model, and so on. Compared with disks, NVM devices are directly
connected to the memory bus, and hence can be accessed by ordinary load and store instructions, at cache-line granularity.
Accesses to NVM are directly backed by the processor cache, which has hardware controlled cache management policy.
In contrast, disks are mostly accessed with block transfers, which is backed by an operating system controlled 
software buffer cache. Compared with DRAM, NVM features slightly slower reads and much slower writes. In addition, 
execssive writes to the same physical location may cause NVM to wear out and become incapable to record data reliably. 
To avoid this from happening, most NVM devices are equipped with firmware that maintains an internal mapping, which maps 
write operations on the same logical address to different locations, minimizing wear. As a result, algorithm for NVM 
should be designed in such a way that data overwriting is minimum.

Existing libraries 
