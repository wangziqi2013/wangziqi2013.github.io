---
layout: paper-summary
title:  "Clobber-NVM: Log Less, Re-execute More"
date:   2021-05-09 17:17:00 -0500
categories: paper
paper_title: "Clobber-NVM: Log Less, Re-execute More"
paper_link: https://dl.acm.org/doi/10.1145/3445814.3446722
paper_keyword: NVM; Clobber Logging; iDO; JUSTDO; Semantics Logging; Resumption
paper_year: ASPLOS 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents Clobber-NVM, a transactional framework for Non-Volatile Memory using recovery-via-resumption.
The paper noted that previous undo or redo logging-based schemes are inefficient, since they need to persist all 
memory writes performed on persistent data. This essentially doubles the amount of traffic to the NVM device.
In addition, if redo logging is used, reads must be redirected to the log in order to access the most up-to-date data.
The paper also noted that previous recovery-via-resumption methods, such as JUSTDO logging and iDO logging,
both have their problems.
JUSTDO logging requires a persistent cache hierarchy which is not yet available, and will likely not be 
commercialized in the future. It only saves the address, data and program counter of the most recent store 
operation in a FASE, without having to maintain a full log. On crash recovery, the machine state is immediately
restored to the point where the last store happens, and the execution of the FAST continues from that point.
It is essentially just an optimization for persistent cache architecture.
