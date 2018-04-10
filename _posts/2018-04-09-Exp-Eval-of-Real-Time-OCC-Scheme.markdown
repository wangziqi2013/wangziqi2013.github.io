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
as transactions lock their write sets. R-Locks and V-Locks are incompatible. The compatibility
matrix, however, is not symmetric. Acquiring R locks on items already locked by a V-Lock causes the requesting
transaction to wait. In contrast, acquiring V locks on items alreadyed locked by a V-Lock or R-Lock indicates
a FOCC violation. This will cause the contention manager to be invoked and abort one of the violating transactions.
Locks are managed by a global lock table (LT).

Two variants are proposed by this paper. The first variant features serial validation and write phase, and is called
OCCL-SVW. On transaction commit, the transaction first enters a critical section, which blocks other commit
and read request. V-Locks are not needed in this case, as the validation and write phases are within the same
critical section. Lock conflicts, however, should be checked. For each dirty data item,
the validation routine checks that no R-Lock is currently held before the validating transaction enters write phase. 
Otherwise, the contention manager is invoked. In order for read requests to be blocked during validation, read
operations should use the same critical section as the validation operation. Otherwise, conflicts can be missed if
a read is performed after validation checks the data item's R-Lock.

The serialized validation and write phases can become a performance bottleneck if transactions commit frequently.
In fact, if transactions rarely conflict on their write sets, most of the commits can concurrently take place, while
only a small fraction needs to be blocked from proceeding till the conflicting transaction finishes commit.

The second variant loosens the restriction that validation and write phases must be performed in a critical section.
To compensate the extra risk that transactions may happen to read a data item after the lock mode for the data item
is checked and before the new value is written back, the committing transaction must lock its write set using V-Locks.
During the read phase, reads and pre-writes acquire R-Locks in a critical section. Note that pre-write operations 
also need R-Locks. During validation, the transaction first enters a critical section, and then acquires V-Locks
on all items in its write set. If a conflict is detected between V-Lock and R-Lock during this phase, the 
validation fails. After locking the write set, the transaction exits the critical section. Dirty values are then
written back without any critical section. Ater that, the transaction enters the critical section for the second time,
and releases all V-Locks it has been holding on the write set. This protocol is called OCCL-PVW, where P stands for
"Parallel".

The OCCL-PVW differs from OCCL-SVW in two important aspects. The first is that the former requires R-Locks be taken
also for pre-write operations. This is because otherwise two transactions that write the same set of data items can
conflict on V-Locks. The paper somehow claims this as undesirable without further explanation. The second difference 
is that the committing transaction exits the critical section after validation without releasing V-Locks on the write 
set. It then performs write back without any critical section. Holding V-Locks during the write back prevents reading
transactions from pre-writing any item in the write set, because otherwise, they may begin commit and try to acquire 
V-Locks on these items, causing V-V lock conflicts.

Deadlock is never a problem of OCCL-PVW. Since all V-Locks are acquired inside a critical section, no interleaving
of lock acquisitions can occur, and hence transactions will not wait for each other. Furthermore, as OCCL-PVW
prohibits V-V lock conflict for some unknown reason, in fact V-Lock requests can only interfere with R-Locks, which
invokes the contention manager.
