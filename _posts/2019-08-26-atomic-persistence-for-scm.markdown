---
layout: paper-summary
title:  "Atomic Persistence for SCM with a Non-Intrusive Backend Controller"
date:   2019-08-26 02:38:00 -0500
categories: paper
paper_title: "Atomic Persistence for SCM with a Non-Intrusive Backend Controller"
paper_link: https://ieeexplore.ieee.org/abstract/document/7446055
paper_keyword: Logging; NVM; Memory Controller
paper_year: HPCA 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a lightweight method for implementing atomic persistent regions by using redo logging. Traditionally
there are three ways of ensuring atomicity with NVM: undo logging, redo logging, and shadow mapping. Undo logging requires
write ordering between the log entries and dirty cache lines, such that dirty data can never reach NVM before the log
entry does. Enforcing such write ordering is expensive on some architectures, and involves changing the cache hierarchy
directly. Shadow mapping, on the other hand, allows the same address to be mapped to different physical locations using
a mapping table, enabling background persistence of different "layers" or "versions". The mapping table, however, must also
be kept crash-consistent such that the after-crash recovery routine can still access persisted data. Such a change also
involves non-trivial hardware change and run time metadata cost. 

The paper