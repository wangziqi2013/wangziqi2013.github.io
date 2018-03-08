---
layout: paper-summary
title:  "EazyHTM: Eager-Lazy Hardware Transactional Memory"
date:   2018-03-07 22:37:00 -0500
categories: paper
paper_title: "EazyHTM: Eager-Lazy Hardware Transactional Memory"
paper_link: https://timharris.uk/papers/2009-micro.pdf
paper_keyword: Conflict resolution; Directory based coherence; 2 Phase Commit
paper_year: 2009
rw_set: L1 Cache
htm_cd: Eager
htm_cr: Lazy
version_mgmt: Lazy
---

This paper proposes a restricted HTM design, EazyHTM (EArly + laZY) that decouples conflict detection (CD) from conflict resolution (CR). 
While prior designs usually do not distinguish between CD and CR, and use either early or late for both, EazyHTM detects conflicts early, 
but delays the resolution to commit time. This scheme addresses one of the problems of early conflict resolution, where
one txn aborts another txn, and then itself is later aborted, resulting in wasted work. This can be avoided if the hardware 
delays conflict processing till commit time, allowing better degree of parallelism. On the other hand, however, the commit process 
will be unnecessarily slowed down if conflicts are detected via a validation phase before commit, because conflicts themselves were 
already known when they took place during the processing phase. 

To minimize wasted work while keeping the commit protocol simple, EazyHTM adopts eager CD but postpones CR till commit point. It assumes
a directory based cache coherent system. The observation is that speculative stores during txns can be treated as load operations 
only assigned 