---
layout: paper-summary
title:  "Improving the Performance of an Optimistic Concurrency Control Algorithm Through Timestamps and Versions"
date:   2018-03-20 17:03:00 -0500
categories: paper
paper_title: "Improving the Performance of an Optimistic Concurrency Control Algorithm Through Timestamps and Versions"
paper_link: http://ieeexplore.ieee.org/document/1702279/
paper_keyword: BOCC; Version validation
paper_year: 1985
rw_set: N/A
htm_cd: N/A
htm_cr: N/A
version_mgmt: N/A
---

Classical BOCC validates read sets serially by intersecting the read set with write sets of earlier transactions
(i.e. those who entered validatin & write phase earlier than the validating transaction). To reduce the number
of write sets to test, a global timestamp counter is used to order transaction write phase and begin. 
The value of the counter indicates the most recent transaction that finished the write phase.
In this scheme, since validation phase and write phase are in the same critical section, the order
that transaction finishes write phase is also the order they enter validation.
Every time a new transaction begins, it takes a snapshot of the counter, ct1. All
write phases that finish after ct1 (and hence have a finish timestamp no less than ct1) can potentially interfere with the 
new transaction's read phase. On transaction commit, it first waits for the previous write phase currently in the critical 
secton to finish, then enters the critical section, and take a second snapshot of the timestamp counter, ct2. 
All write phases that **start** before ct2 (and hence have a **finish** timestamp less than ct2) can potentilaly
interfere with the new transaction's read phase. The new transacton, therefore, validates all write sets that have 
a finish timestamp between ct1 and ct2.