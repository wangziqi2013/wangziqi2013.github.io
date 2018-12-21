---
layout: paper-summary
title:  "Multi-Version Concurrency via Timestamp Range Conflict Management"
date:   2018-12-20 16:53:00 -0500
categories: paper
paper_title: "Multi-Version Concurrency via Timestamp Range Conflict Management"
paper_link: https://ieeexplore.ieee.org/document/6228127
paper_keyword: Concurrency Control; MVCC; OCC; Interval-Based CC
paper_year: ICDE 2012
rw_set: Software
htm_cd: N/A
htm_cr: N/A
version_mgmt: N/A
---

This paper presents Transaction Conflict Manager (TCM), a MVCC transaction processing engine from Microsoft. 
Instead of utilizing multiversioning and only providing Snapshot Isolation (SI), this paper combines multiversioning 
with Optimistic Concurrency Control (OCC), and provides full serializability support. Compared with Two-Phase Locking (2PL), 
this approach allows higher degrees of parallelism, because transactions are allowed to proceed in parallel even if they conflict. 
The conflict is resolved eagerly as in 2PL, but blocking is not always required. Compared with traditional OCC, TCM 
suffers less aborts, because OCC does not tolerate any Write-After-Read (WAR) conflict on running transactions, such that
if WAR is detected no matter if it can be resolved, the transaction must be aborted. In contrast, TCM performs more detailed 
analysis using timestamps and the nature of conflicts, and hence allows more transactions to commit given the same workload
and scheduling compared with OCC.

The storage engine maintains multiple versions of data items. Each version is tagged with a timestamp. On transaction
commit, after the commit timestamp has been selected, the storage engine commits the write set of the transaction and 
tag them with the transaction's commit timestamp. Compared with some schemes which maintains two timestamps per item: 
one for read (rts) and one for write (wts), this scheme could save storage that is dedicated to timestamps. As a compensation,
transactions must hold their soft locks on data items even after they commit. The soft lock requires an extra garbage collection
mechanism in addition to the GC for versions.

Each TCM transaction has two timestamps: a lower bound (lb) which denotes the smallest logical time the transaction could commit,
and an upper bound (ub) which denotes the largest logical time the transaction could commit. If lb and ub cross (i.e. lb becomes 
larger than ub), then the transaction must immediately abort, because a conflict cycle will occur if the transaction commits. 
During the execution of the transaction, the lb and ub are adjusted dynamically according to the execution of concurrent 
transactions. We next discuss how transactional operations are handled in detail.

On transaction begin, lb is initialized to the current time, and ub is initialized to +&infin;. The source of "current time"
can either be a real time clock with sufficient precision, or a software counter that is atomically incremented after every
timestamp read. Note that this is different from some data-driven timestamping schemes, where the lb is initialized to 
zero, and will be adjusted according to the rts or wts of data items it accesses as a means of serializing committed 
transactions. In TCM, transactions do not serialize against committed transactions using rts or wts. Instead, the transaction
is assigned a timestamp that allows it to access the most current snapshot of the state, which can be only increased but 
not decreased. 

On transactional read, the TCM traverses the version chain beginning from the most up-to-date version to older versions. 
The first version whose timestamp is less than the lb of the transaction during the traversal will be used to fulfill the read
operation. This way, we are guaranteed that the transaction can always access a consistent snapshot at logical time lb.
A soft read lock is also acquired to ensure that later writing transactions on this item will serialize with the current transaction,
as we will show later.