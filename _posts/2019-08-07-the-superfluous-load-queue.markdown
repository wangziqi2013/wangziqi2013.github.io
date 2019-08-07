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
the illustration that instructions are executed one by one in the program order, load instructions should always 
read the most recent value written by the same processor if there is no remote store. The store instruction, however,
may still be in the pipeline (and also store queue) and has not been committed; or even if it has been committed, it may 
stay in the store buffer for a while just to wait for L1 to acquire line ownership. It is therefore insufficient simply 
let the load instruction check the L1 cache. In fact, all these three structures should be checked, and whether the 
load is allowed to continue execution depends on the result of the checking. If there is an older store instruction in 
the store queue, and its address has not yet been fully calculated, there is no way for the load to forward or bypass 
the store. In most designs, the load instruction will simply assume that the older store does not conflict with itself,
and then proceed. In the (relatively) rare case that a conflict truly happens, this leads to incorrect result, because 
the value returned from the load instruction is not the most recent store. To counter this, 