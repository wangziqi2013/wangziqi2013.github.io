---
layout: paper-summary
title:  "Lease/Release: Architectural Support for Scaling Contended Data Structures"
date:   2019-01-11 16:37:00 -0500
categories: paper
paper_title: "Lease/Release: Architectural Support for Scaling Contended Data Structures"
paper_link: https://dl.acm.org/citation.cfm?doid=2851141.2851155
paper_keyword: Cache Coherence; Concurrent Data Structure; Locking; Lock-free
paper_year: PPoPP 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Lease/Release, a mechanism for reducing unnecessary memory coherence traffic in lock-free and lock-based
data structure implementation. The paper identifies three major sources of unnecessary memory traffic. First, when a lock
is acquired, the exclusive ownership is obtained by the acquiring processor. If another processor would like to acquire 
the same lock, it has to acquire exclusive ownership of the line, forcing an ownership transfer, only to find out that the 
lock is currently held by the first processor. When the first processor releases the lock, it has to acquire the cache line 
again to perform the write. In this case, the memory traffic can be reduced if the second processor does not obtain the 
cache immediately, but only after the first processor releases the lock.