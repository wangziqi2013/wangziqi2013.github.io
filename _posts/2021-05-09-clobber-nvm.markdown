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
