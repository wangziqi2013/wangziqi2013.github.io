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

NVthreads 
