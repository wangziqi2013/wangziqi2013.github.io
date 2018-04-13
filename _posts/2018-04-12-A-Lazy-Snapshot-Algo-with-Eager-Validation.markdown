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
use the counter. As transactions access data items, they intersect their intervals with the valid 
ranges of data items that they access. If the resulting interval is non-empty, then the access is 
guaranteed to be valid, and requires no extra validation. The intersection, however, can become empty 
because the data item's lower bound is larger than the transaction's upper bound (the reverse will not
happen, because if the transaction could not read an item which has been overwritten before it starts). 
In this case, the transaction validates the current read set, and "extends" the upper bound of its interval 
to the current global time.

A transaction extends its upper bound by performing an incremental validation. For all versions in its read
set, it tests whether the version's most up-to-date upper bound is smaller than the current global time 
(the most up-to-date version has an upper bound of +\&infin;). Note that an overwrite on data items will
update both the previous version's upper bound and the new version's lower bound atomically. If the upper
bound of all data items is still no smaller than the current global time, then the transaction has been
extended to the current global time. Extension by incremental validation is logically valid, because as long 
as the current stage of validation succeeds, transactions committed between the begin and the current global
time does not write into the read set of the validating transaction. The serialization order between committed
transactions and the validating transaction, therefore, is not defined until the validating transaction commits. 
