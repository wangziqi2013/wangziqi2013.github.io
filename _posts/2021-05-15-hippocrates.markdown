---
layout: paper-summary
title:  "Hippocrates: Healing Persistent Memory Bugs without Doing Any Harm"
date:   2021-05-15 21:43:00 -0500
categories: paper
paper_title: "Hippocrates: Healing Persistent Memory Bugs without Doing Any Harm"
paper_link: https://about.iangneal.io/assets/pdf/hippocrates.pdf
paper_keyword: NVM; Bug Finding; Hippocrates
paper_year: ASPLOS 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents Hippocrates, a bug-fixing utility for NVM-based applications.
The paper notices that persistence-related bugs (durability bugs) in NVM oriented applications are hard to find 
but easy to fix.
Existing tools are often capable of finding write ordering violations in dynamic execution traces, but not able
to fix them automatically. 
Some other tools are targeted at fixing general bugs in application code, but they do not guarantee the eventual
correctness of the program, or may introduce new bugs.