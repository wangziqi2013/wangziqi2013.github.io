---
layout: paper-summary
title:  "Relaxed Persist Ordering Using Strand Persistency"
date:   2020-12-27 21:19:00 -0500
categories: paper
paper_title: "Relaxed Persist Ordering Using Strand Persistency"
paper_link: https://ieeexplore.ieee.org/document/9138920
paper_keyword: NVM; Write Ordering; Strand Persistency; StrandWeaver
paper_year: ISCA 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes strand consistency and a hardware implementation, StrandWeaver, to provide a better persist 
barrier semantics and a more efficient implementation than current designs. Persist barriers are essential to NVM
programming as it orders store operations to the device, which is utilized for correctness in many logging-based 
designs. For example, in undo logging, log entries must reach the NVM before dirty data, and dirty data must be flushed
back before the commit mark is written. Similarly, in redo logging, redo log entries must be ordered before the commit
mark, which is then ordered before all dirty data.

