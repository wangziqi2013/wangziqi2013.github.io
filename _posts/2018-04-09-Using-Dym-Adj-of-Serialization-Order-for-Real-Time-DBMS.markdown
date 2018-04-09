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
in detail, so we only discuss what is not covered previously after a brief overview of the algorithm outline.

The time interval based OCC (TIOCC) differs from classical BOCC such that the serialization order of 
transactions is not determined by the order they start validation. Instead, each transaction is assigned 
a time interval in which the transaction is logically consistent. The commit timestamp of transactions are
selected from this time interval. Each data item is associated with most recent read and write timestamps 
(rts and wts respectively). These timestamps are updated whenever a transaction that reads or writes them
commits. When a reading transaction accesses these data items, it adjusts the time interval