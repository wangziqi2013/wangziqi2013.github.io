---
layout: paper-summary
title:  "A Lazy Snapshot Algorithm with Eager Validation"
date:   2018-04-12 20:09:00 -0500
categories: paper
paper_title: "A Lazy Snapshot Algorithm with Eager Validation"
paper_link: https://dl.acm.org/citation.cfm?id=2136071
paper_keyword: LSA-STM;
paper_year: 2006
rw_set: Set
htm_cd: Incremental Eager
htm_cr: Eager
version_mgmt: Lazy
---

This paper provides another view to the Backward OCC algorithm. The classical way models BOCC 
problems as preventing overlapping read and write phases via either timestamps or set intersections.
This paper proposes an interval-based approach. Each transaction, at the transaction beginning, is 
assigned a valid interval of [CT, +&infin;). Each instance of the data item also has a valid range.
The lower bound of the valid range is defined by the commit timestamp (ct) that creates the particular
version of the data item. The upper bound of the valid range is defined as the ct of a later transaction
that overwrites the item. The overwrite of a data item by a committing transactions updates the 
upper bound of the previous version and the lower bound of the new version atomically.

Transaction commits are serialized by a global timestamp counter as in other BOCC algorithms that
use the counter.
As transactions access data items, they intersect their intervals with the valid ranges of data 
items that they access. If the resulting interval is non-empty, then the access is guaranteed to
be valid, and requires no extra validation. If, however, that after the intersection, the interval
becomes empty, then the transaction validates the current read set, and "extends" the upper bound
of its interval to the current global time.