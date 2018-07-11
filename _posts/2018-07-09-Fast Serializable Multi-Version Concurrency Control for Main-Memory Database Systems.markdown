---
layout: paper-summary
title:  "Fast Serializable Multi-Version Concurrency Control for Main-Memory Database Systems"
date:   2018-07-09 23:58:00 -0500
categories: paper
paper_title: "Fast Serializable Multi-Version Concurrency Control for Main-Memory Database Systems"
paper_link: https://dl.acm.org/citation.cfm?doid=2723372.2749436
paper_keyword: MVCC; Hyper
paper_year: SIGMOD 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Multiversion Concurrency Control (MVCC) has been widely deployed with commercial databases such as PostgreSQL,
OracleDB and SQL Server. Most MVCC systems use timestamps to synchronize transactions. We describe a baseline 
implementation of MVCC here as the foundation of the following discussion. Our baseline MVCC uses dual-timestamp
scheme, which is a common choice for commercial MVCC implementations. Every transaction obtains a begin timestamp
from a global timestamp counter at transaction start. The begin timestamp is used by the transaction during its 
execution to access the correct version of data items. When writing transaction commits, it obtains a commit timestamp
using atomic Compare-and-Swap (CAS) from the same global timestamp counter as it obtained the begin timestamp. New versions
of data items are created, which are tagged with the commit timestamp of the transaction that writes the data item. 
Different versions of the same data item are linked together in sorted commit timestamp order, from the most recent
to the least recent. This structure is called a version chain. On transactional read, the transaction locates the most 
recent version whose commit timestamp is less than or equal to the begin timestamp by traversing the version chain from
the head. If the version could not be found (e.g. if the Garbage Collector has already freed the target version), the 
reading transaction aborts and acquires a newer begin timestamp before retry. On transactional write, the 
transaction buffers the write operation as well as the new value of the data item into local storage, which is not yet 
visible to other transactions. For MVCC, the local storage can be omitted because the transaction could just creates a 
new version and adds it into the version chain. The commit timestamp of the uncommitted version should be somehow greather
than all possible begin timestamps in the system to avoid uncommitted read. Note that in SQL Server Hekaton this is not
the case, as writing transactions allow other transactions to read uncommitted data, as long as the latter establishs
a commit dependency with the former to guarantee recoverable execution. 

On transaction commit, transactions validate themselves by verifying the read and/or write set. The concrete validation
algorithm depends on the isolation level. We only consider Snapshot Isolation (SI) and Serializable here. For Snapshot Isolation, 
transactions must ensure the integrity of the write set, i.e. no other transaction has committed on the write set of the 
committing transaction. The verification proceeds by checking the most recent version on the version chain for every item 
in the write set. If the version has a commit timestamp greater than the begin timestamp, then validation fails and current 
transaction must abort. This validation rule is usually called "First Committer Wins", because if two transactions conflict 
by writing the same data item, the one that commits first wins and the other must abort. As an alternative, OracleDB detects 
write-write conflcits eagerly, which is called "First Writer Wins". Transactions that speculatively write a data item needs to 
lock the item first. If the lock is already held by another transaction, then a write-write conflict is detected, and the 
transaction aborts. The write set is also checked during validation. On the other hand, to achieve Serializable, transactions
must verify that their read sets are not changed by concurrenct transactions. This is usually implemented as re-reading 
all data items in the read set and checking their most up-to-date versions after locking data items in the write set.
In either case, if the validation returns successfully, then a commit timestamp is obtained, and speculative data items
are made public by tagging them with the commit timestamp.

In practice, MVCC is favored by commercial database vendors over other concurrency control schemes 
such as Optimistic Concurrency Control (OCC) and Two-Phase Locking (2PL) for the following reasons. First, compared with
2PL, transactions running MVCC do not wait for other transactions to finish if conflict occurs. Instead, for read-write 
conflicts, transactions are able to time travel and locate an older version of the data item, while the resolution of 
write-write conflicts can be optionally postponed to commit time. Allowing multiple conflicting transactions to run in
parallel greatly increases the degree of paralellism of the system, and on today's multicore platform this feature prevents
processors from being putting into idle state frequently. Second, since MVCC does not employ any form of busy waiting
based on transactional reads and writes, no deadlock is ever possible