---
layout: paper-summary
title:  "Rethinking File Mapping for Persistent Memory"
date:   2021-06-12 16:33:00 -0500
categories: paper
paper_title: "Rethinking File Mapping for Persistent Memory"
paper_link: https://www.usenix.org/system/files/fast21-neal.pdf
paper_keyword: NVM; File System; Cuckoo Hashing
paper_year: FAST 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents two low-cost file mapping designs optimized for NVM. The paper observes that, despite the 
fact that file mapping accesses may constitute up to 70% of total I/Os in file accessing, little attention has been
paid to optimize this matter for file systems specifically designed for NVM.
The performance characteristics of NVM also makes it worth thinking about redesigning the file mapping structure.

