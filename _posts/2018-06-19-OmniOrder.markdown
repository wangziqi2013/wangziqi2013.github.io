---
layout: paper-summary
title:  "OmniOrder: Directory-Based Conflict Serialization of Transactions"
date:   2018-06-19 22:55:00 -0500
categories: paper
paper_title: "OmniOrder: Directory-Based Conflict Serialization of Transactions"
paper_link: https://ieeexplore.ieee.org/document/6853223/
paper_keyword: HTM; OmniOrder; Sequential Consistency
paper_year: ISCA 2014
rw_set: On-chip buffer
htm_cd: Eager
htm_cr: Eager
version_mgmt: Eager (Uncommitted Read)
---

Conflict-based Hardware Transactional Memory (HTM) suffers from high abort rates when conflicts are frequent.
This is caused by the simple conflict detection mechanism which treats any cache coherence message that hits 
transactional cache lines as potential sources of violation. The only exception to this rule is bus read shared 
request on shared or exclusive lines, as reader processor cannot conflict with other readers. Processors 
will abort and restart if a conflict is detected. This property is sub-optimal, because not all dependencies 
imply violations at the end of the execution.