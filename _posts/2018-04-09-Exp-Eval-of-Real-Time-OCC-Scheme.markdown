---
layout: paper-summary
title:  "Experimental Evaluation of Real-Time Optimistic Concurrency Control Schemes"
date:   2018-04-09 19:00:00 -0500
categories: paper
paper_title: "Experimental Evaluation of Real-Time Optimistic Concurrency Control Schemes"
paper_link: http://www.vldb.org/conf/1991/P035.PDF
paper_keyword: FOCC
paper_year: 1991
rw_set: Lock Table
htm_cd: Eager (FOCC)
htm_cr: Eager (FOCC)
version_mgmt: Lazy
---

This paper proposes an implementation of Forward OCC (FOCC) using shared and exclusive locks.
The algorithm specification of classical FOCC requires that the write set of the committing
transaction be broadcasted to all reading transactions. A contention manager is 
invoked if any reading transaction has a non-empty overlap with the committing transaction,
and either the reading or the committing transaction must be aborted. A direct translation
of this logical description can be difficult. For example, broadcasting capability is assumed 
by the specification. In systems without native support for broadcasting, this must
be somehow emulated.

One of the many approaches is to use lock. Two lock modes are required. The first is shared mode 
(R-Lock, R for "Reading"), which is acquired during the read phase as transactions read and pre-write data items.
The second is exclusive mode (V-Lock, V for "Validating"), which is acquired during the validation phase
as transactions lock their write sets. R-Locks and V-Locks are in general incompatible. The compatibility
matrix, however, is not symmetric. Acquiring R locks on items already locked by a V-Lock causes the requesting
transaction to wait. In contrast, acquiring V locks on items alreadyed locked by a V-Lock or R-Lock indicates
a FOCC violation. This will cause the contention manager to be invoked and determine one of the violating transactions.
Locks are managed by a global lock table (LT).


