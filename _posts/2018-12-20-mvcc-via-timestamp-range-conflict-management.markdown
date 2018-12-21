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

On transactional read, the TCM traverses the version chain beginning from the most up-to-date version towards older versions. 
The first version whose timestamp is less than the lb of the transaction during the traversal will be used to fulfill the read
operation. This way, we are guaranteed that the transaction can always access a consistent snapshot at logical time lb.
A soft read lock is also acquired to ensure that later writing transactions on this item will serialize with the current transaction,
as we will show later. 

If a conflicting lock mode has already been acquired by another transaction (i.e. a writer transaction), the current transaction
will try to resolve the conflict eagerly by adjusting either its timestamp or the timestamp of the other transaction. 
TCM maintains a lock manager that operates exactly the same as an ordinary lock manager except that it does not always block.
On a conflict, the lock manager returns the list of transactions that are incompatible with the current requestor, which 
will be used for the next step of conflict resolution. In most cases, the reader transaction should be able to serialize before 
uncommitted writes by forcing the writer transaction's lb to shrink (and also lowering its ub), after which the reader could 
proceed without blocking. If the above is not possible, then the reader transaction will fall back and serialize after the 
uncommitted write by adjusting its lb to a higher value (and also lowering the other transaction's ub). The transaction
will then be blocked, because in order to access the uncommitted data item, the writer transaction must commit first.
There are very rare cases when the reader and writer transactions' interval are identical. The reader must abort in this
case, because there is no way to serialize.

On transactional write, the TCM buffers dirty data in a transactional-local area. The data item is also write locked.
The lock manager returns the list of conflicting lock holders, if any. If the write operation conflicts with any other 
running transaction, the current transaction will try to serialize against them by adjusting intervals. There are two cases 
two consider. First, if the current transaction conflicts with an uncommitted read, the former will try to serialize 
after the reader, as the latter does not observe the uncommitted write value. This is done whenever possible by raising 
the lb of the current transaction (and also lowering the ub of the reading transaction). Otherwise, the write transaction
serializes before the reader transaction using similar adjustments to the lb and ub, after blocking and waiting the 
reader to commit first. In the second case, the lock holder is a writing transaction. The current transaction can only choose
to serialize after it, and then block. If serialization is not possible, the current transaction immediately aborts, 
because TCM does not allowing write operations to be serialized before another uncommitted write.

On transaction commit, no extra validation is required, because the CC scheme detects and resolves conflicts eagerly. 
The transaction simply tests whether its interval is still valid, and if it is, writes back all dirty values by creating 
new versions. The commit timestamp is chosen as the earliest possible timestamp in the interval. 

After the transaction commits, the soft locks must not be immediately released. This is because future reads and writes 
may still have to serialize against committed operations. Delayed lock release is required as a compensate for lacking
read timestamps. For example, assume transaction A reads version 90, and commits at 100. If another transaction B wishes 
to write a value, the timestamp of B must at least be 101, because A did not read the value written by B and hence 
is serialized before B. If A removes the soft read lock after it commits, there is no way for B to know that it could not 
use a timestamp between 90 and 100. If B eventually commits at 95, serializability is violated. To garbage collect
soft locks on data items, the TCM must make sure that the soft lock is only removed when it can no longer affect the 
interval of active and future transactions. 