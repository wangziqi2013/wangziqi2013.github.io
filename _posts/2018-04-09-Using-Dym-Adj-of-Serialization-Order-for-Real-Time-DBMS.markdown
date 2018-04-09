---
layout: paper-summary
title:  "Using dynamic adjustment of serialization order for real-time database systems"
date:   2018-04-08 16:15:00 -0500
categories: paper
paper_title: "Using dynamic adjustment of serialization order for real-time database systems"
paper_link: https://ieeexplore.ieee.org/document/393514/
paper_keyword: FOCC; TIOCC
paper_year: 1993
rw_set: Lock Table
htm_cd: Eager (FOCC)
htm_cr: Eager (FOCC)
version_mgmt: Lazy
---

This paper proposes a time interval based OCC algorithm. The algorithm has been discussed in [another
paper review]({% post_url 2018-04-07-Concurrent-Certifications-by-Intervals-of-ts-in-distributed-dbms %}) 
in detail, so we only discuss what is not covered previously. Before that, we first go through a brief 
overview of the algorithm outline.

The time interval based OCC (TIOCC) differs from classical BOCC such that the serialization order of 
transactions is not determined by the order they start validation. Instead, each transaction is assigned 
a time interval in which the transaction is logically consistent. The commit timestamp of transactions are
selected from this time interval when they are about to commit. Each data item is associated with most recent 
read and write timestamps (rts and wts respectively). These timestamps are updated whenever a logically newer 
transaction that reads or writes them commits. When a reading transaction accesses these data items, it adjusts 
the time interval based on the type of operation and either the rts or wts of the data item. For example, when
reading a data item, the lower bound of the interval is set to the old lower bound or the wts, whichever is 
larger. Similarly, when pre-writing a data item in the read phase, the lower bound of the interval is set to the 
old lower bound or the rts, whichever is larger. The goal of tightening the interval's lower bound is to serialize
the current reading transaction after committed transactions. On transaction commit, the committing transaction
first enters a critical section which blocks commit requests and data item access requests. Then the committing 
transaction's write set is broadcasted to all reading transactions together with the selected commit timestamp. 
On receiving the broadcast, reading transactions compare the write set with its own read and write set. If the 
write set has a non-empty intersection with its read set, then the upper bound of the interval is set to the 
old upper bound or the braodcasted commit timestamp, whichever is smaller. If the write set has a non-empty intersection
with its write set, then the lower bound of the interval is set to the old lower bound or the broadcasted commit 
timestamp. whichever is larger. The FOCC-style interval adjustment serializes reading transactions with the 
transaction just committed, as if the commit operation logically happens after all uncommitted reads, and 
before all uncommitted writes. If in any of the above cases, the interval closes after the adjustment, i.e. the upper 
bound crosses the lower bound, then the current transaction must abort as it can no longer serialize with committed 
transactions. Otherwise, if a committing transaction passes validation, it enters write phase, in which all dirty 
values are written back and timestamps of data items are updated accordingly.