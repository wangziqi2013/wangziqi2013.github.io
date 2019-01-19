---
layout: paper-summary
title:  "Delegated Persist Ordering"
date:   2019-01-19 04:33:00 -0500
categories: paper
paper_title: "Delegated Persist Ordering"
paper_link: https://ieeexplore.ieee.org/document/7783761
paper_keyword: Undo Logging; Persistence Ordering; NVM
paper_year: MICRO 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Delegated Persiste Ordering, a machanism for enforcing persistent write ordering on platforms
that support NVM. Persistence ordering is crucial to NVM recovery applications, because it controls the order that dirty
data is written back from volatile storage (e.g. on-chip SRAM, DRAM buffer, etc.) to NVM. For example, in undo logging, two
classes of write ordering must be enforced: First, the log entry must be persisted onto NVM before dirty items does, because
otherwise, if a crash happens after a dirty item is written back and before its corresponding undo log entry, there is no
way to recover from such failure. Second, all dirty items must be persisted before the commit record is written on the NVM
log. If not, the system cannot guarantee the persistence of committed transactions, since unflushed dirty items will be 
lost on a failure. Without significant hardware addition, in order to enforce persistence ordering on current platforms,
programmers must issue a special instruction sequence which flushes the dirty cache line