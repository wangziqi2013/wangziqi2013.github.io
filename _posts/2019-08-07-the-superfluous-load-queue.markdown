---
layout: paper-summary
title:  "The Superfluous Load Queue"
date:   2019-08-07 17:18:00 -0500
categories: paper
paper_title: "The Superfluous Load Queue"
paper_link: https://ieeexplore.ieee.org/document/8574534
paper_keyword: Load Queue; Speculative Execution; TSO
paper_year: ISCA 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Load queue has long been used in microarchitectures as one of the many hardware structures that support speculation.
When a load instruction is inserted into the reordered buffer (ROB), an entry is also allocated in the load queue
which contains full information of the instruction just as in the ROB. Load instructions are inserted into the load
queue in the program order (because the front end inserts into the ROB in the program order). During the execution, three
conditions are checked to ensure both correct program semantics and memory consistency guarantees. First, to maintain
the illustration that instructions are executed one by one in the program order, 