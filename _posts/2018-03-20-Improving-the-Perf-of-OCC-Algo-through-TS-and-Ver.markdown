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

Instead of performing set intersections, which requires (# of write sets * # size read set) hash table probing (we assume
write sets are implemented as O(1) probe time hash table), timestamps are assigned to each data item in the system. 
During the serial validation phase, transaction obtain commit timestamps (ct) from the global timestamp counter.
Then, in the write phase, they update timestamps of items in write sets to ct. Furthermore,
when transactions begin their first read operation, they obtain a begin timestamp (bt). Validation is
performed by comparing the timestamp of data items in the read set with bt. If the timestamp is greather than bt,
then obviously some transaction's write phase has written into it after the validating transaction started. 

<hr />
<br />
![Version Based Validation]({{ "/static/ver-validation/figure1-wrong-algo.png" | prepend: site.baseurl }} "Version Based Validation"){: width="600px"}
<br />
**Figure 1: The Version-Based Validation and Write Back**
{: align="middle"}
<hr /><br />

The original version-based vaidation in the paper, however, is incorrect. As shown in Figure 1