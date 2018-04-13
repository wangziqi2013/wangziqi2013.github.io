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
If the incremental validation fails, the transaction must abort if it is an updating transaction, because the
write phase must be performed on a most up-to-date snapshot.

For read-only transactions, the serialization condition can be less restrictive, as they do not update
global state. Read-only transactions, if equipped with the ability to read older versions (the 
version storage itself must be multi-version enabled), can "time travel" backwards in the logical time. 
The result of such time travel is that the logical serialization order of read-only transactions could 
be even earlier than the logical time it starts. When a read is performed, the transaction tries to find 
the newest version whose lower bound is smaller than the transaction's upper bound. If the version is
available, and has been overwritten, then the transaction "closes" its upper bound, because it can no
longer be extended ("time travel" forward in time). The upper bound of the read-only transaction is also
set to either the upper bound of the transaction before the read operation, or the upper bound of the data 
item, whichever is smaller. If no such version is available, then the read-only transaction aborts.

The paper gives a detailed description of the incremental BOCC algorithm, which is dubbed as the "Lazy
Snapshot Algorithm" (LSA). Write phase is not covered in the description, nor does it give concrete solutions
about the version storage, the garbage collection problem, etc.
