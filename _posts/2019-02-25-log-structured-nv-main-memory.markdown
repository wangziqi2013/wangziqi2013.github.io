---
layout: paper-summary
title:  "Log-Structured Non-Volatile Main Memory"
date:   2019-02-25 13:20:00 -0500
categories: paper
paper_title: "Log-Structured Non-Volatile Main Memory"
paper_link: https://www.usenix.org/system/files/conference/atc17/atc17-hu.pdf
paper_keyword: Log-Structured; NVM; Durability
paper_year: USENIX ATC 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes log-structured Non-Volatile Main Memory (LSNVMM) as an improvement to more traditional NVMM designs
that use Write-Ahead Logging (WAL). The paper identifies two problems with WAL-based NVM designs. First, WAL doubles the 
number of write operations compared with normal execution. Either undo or redo log entry is generated for every store 
operation, which will then be persisted onto the NVM using persiste barriers or dedicated hardware. In the case where NVM 
bandwidth is the bottleneck, overall performance will be impacted by the extra store operation. The 