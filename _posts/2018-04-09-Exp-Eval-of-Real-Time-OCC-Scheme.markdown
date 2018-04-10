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
transaction be broadcasted to all reading transactions. A conflict resolution manager is 
invoked if any reading transaction has a non-empty overlap with the committing transaction,
and either the reading or the committing transaction must be aborted. A direct translation
of this logical description may be difficult. For example, broadcasting capability is assumed 
by the logical specification. In systems without native support for broadcasting, this must
be somehow emulated.

Locking can be used to implement FOCC
