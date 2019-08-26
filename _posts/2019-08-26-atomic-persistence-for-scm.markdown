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

The paper proposes using redo logging to implement atomic persistent transactions. Two problems naturally exist with 
redo logging. First, although redo logging does not require the write ordering between log entries and dirty data 
(since dirty data can always be replayed by applying log entries), dirty data must be kept away from the NVM device
before the transaction is fully committed, because otherwise, there is no way of rolling back these partial changes.
Similarly, the end-of-transaction mark in the redo log must be written before the transaction commits. The second problem
is read redirection into the log every time the cache misses. This happens if the transaction size exceeds the cache 
size and hence some blocks inevitably overflows as a result of capacity miss. These evicted blocks are either discarded 
because their contents are already stored in the log anyway, or they are kept in an L4 cache of the hierarchy, often
implemented as a part-of-DRAM data structure with a mapping table. This mapping does not have to be kept presistent,
because the de facto content of memory after a recovery is recorded in the redo log. On a read cache miss, the bloc must either
be fetched from the log by walking log entries and locating the most recent write, or by querying the in-memory 
mapping table. Such re-direction overhead can be large sometimes, which prevents a load miss from being resolved in
a timely manner.