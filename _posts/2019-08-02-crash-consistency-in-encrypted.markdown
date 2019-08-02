---
layout: paper-summary
title:  "Crash Consistency in Encrypted Non-Volatile Main Memory Systems"
date:   2019-08-02 04:07:00 -0500
categories: paper
paper_title: "Crash Consistency in Encrypted Non-Volatile Main Memory Systems"
paper_link: https://ieeexplore.ieee.org/document/8327018
paper_keyword: NVM; Encryption; Counter Atomicity
paper_year: HPCA 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper introduces counter-atomicity, a concept used for encrypted NVM environment. The paper builds upon the fact
that data stored in NVM devices should be encrypted, because otherwise data can be accessed even after a system shutdown,
rendering memory protection meaningless. This paper levarages counter mode encryption, in which each cache line is tagged 
with a run-time generated counter. On every modification of the line, 