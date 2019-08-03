---
layout: paper-summary
title:  "NVthreads: Practical Persistence for Multi-threaded Applications"
date:   2019-08-03 00:16:00 -0500
categories: paper
paper_title: "NVthreads: Practical Persistence for Multi-threaded Applications"
paper_link: https://dl.acm.org/citation.cfm?doid=3064176.3064204
paper_keyword: NVM; Critical Section; Redo Logging
paper_year: EuroSys 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper introduces NVthreads, a parallel programming framework aiming at providing persistency without burdening 
programmers with modifying existing code to fit into the new paradigm, while being efficient on Non-Volatile devices.
Prior to NVthreads, several NVM frameworks have been proposed. As pointed out by this paper, these proposals are usually 
not user-friendly and/or inefficient for two reasons. First, programmers may be forced to adapt to a new programming
paradigm that is partially or entirely different from what they are used to. This may involve some deep learning curve,
or require changing existing source code. Second, most prior publications focus on utilizing the byte-addressibility
of NVM devices, which implies tracking and persisting changes at the unit of cache line sized blocks (64 Bytes). Although
this scheme sometimes have less storage overhead, the extra cost of persisting every cache line may outweigh the 
storage benefit, and makes the system under-perform. 

NVthreads seeks to solve the above two problems using atomic region inference and page-level redo logging. NVthreads assume 
that programs directly run on an address space mapped to the NVM (i.e. there is no address backed by DRAM, such that all 
cache line evictions will be directed to the NVM device). NVthreads also assume that programmers use the pthread library
for thread synchronization. Notably, this paper assumes programmers will use pthread_lock/unlock and pthread_wait/signal
to implement critical sections and signaling, although other third-party interface can be easily supported. 
