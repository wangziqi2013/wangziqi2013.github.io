---
layout: paper-summary
title:  "Durable Transactional Memory Can Scale with TimeStone"
date:   2020-08-24 18:06:00 -0500
categories: paper
paper_title: "Durable Transactional Memory Can Scale with TimeStone"
paper_link: https://dl.acm.org/doi/abs/10.1145/3373376.3378483
paper_keyword: NVM; MVCC; STM; TimeStone; Redo Logging
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Lowlight:**

1. How does each transaction find the volatile object in the write set? Is there a per-thread mapping table that maps the 
   object's master address to its local write set address?

This paper presents TimeStone, a software transactional memory (STM) framework running on NVM, featuring high scalability 
and low write amplification. The paper points out that existing implementations of NVM data structures demonstrate various
drawbacks.
First, for those implemented as specialized, persistent data structures, their programming model and concurrency model
is often restricted to only single operation being atomic. Composing multiple operations as one atomic unit is most
likely not supported, and difficult to achieve as the internal implementation is hidden from the application developer.
Second, for those implemented as transactional libraries, their implementations lack scalability due to centralized 
mapping structure, metadata, or background algorithms. 
Lastly, conventional logging approach, if adopted, incurs high write amplification, since both log entries and data 
need to be persisted to the NVM.

TimeStone achieves efficiency, scalability, and low write amplification at the same time. TimeStone's design consists 
of two orthogonal aspects. The first aspect is the concurrency control model, which uses Multiversion Concurrency Control 
(MVCC), in which multiple versions of the same logical object may exist to serve reads from different transactions.
MVCC features higher scalability, since only writes will lock the object, while reads just traverse the version chain
to access the consistent snapshot.
Metadata such as locks are maintained in a per-object granularity without any table indirection.
Version numbers are also maintained with each instance of the object copy.
Each logical object may have several copies of different versions stored in NVM and DRAM, forming a version chain from
the most recent to the least recent version.

A global timestamp counter maintains the current logical time as in other MVCC schemes.
On transaction begin, a begin timestamp is acquired, which is used to access object copies. The version access rule states
that a timestamp T should access the least recent version whose commit timestamp, which is part of the per-object
metadata, is smaller than or equal to T, essentially reading the snapshot established at logical begin time T.
Each thread also maintains a local write set as volatile log (allocation is performed in log-structured manner, and reclaimed
with GC), which we discuss later. 
The local write set consists of all objects that are modified during the transaction, which remains private to the 
updating transaction before it commits.

Before an object could be updated, an volatile object copy is allocated in the local write set, the lock is acquired by 
atomically CAS the NULL pointer (NULL means the lock is not acquired) to the volatile object in the write set. If the CAS 
fails, the transaction is aborted, as write-write conflict is detected, which is the abort condition for all supported 
isolation levels. Otherwise, the write wrapper function traverses the version chain, and copies the corresponding version 
based on the version access rule to the volatile log. All updates are then performed in the write set.
Read sets are also maintained, if the isolation level is serializable or linearizable.

At commit time, validation is performed if the read set is present. Read validation succeeds, if for all objects in the 
read set, their accessed version is still the most up-to-date version. Otherwise, the transaction has observed a 
WAR dependency, which violates commit order. After read validation, the transaction acquires its commit timestamp by atomically
fetch-and-increment the global timestamp counter. The value after the increment is used as the commit timestamp.
Objects in the local write set is linked into the version chain as the most up-to-date element, since the write set 
objects are locked as the transaction executes, such that no other transaction could commit on them.
Objects are unlocked after the commit process.
