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
from a global timestamp counter at transaction begin. The begin timestamp is used by the transaction during its 
execution to access the correct version of data items. When writing transaction commits, it obtains a commit timestamp
using atomic Compare-and-Swap (CAS) creates new versions
for data items in its write set. The newly created data items are tagged with the commit timestamp. Data items are tagged with 

In practice, MVCC is favored by commercial database vendors over other concurrency control schemes 
such as Optimistic Concurrency Control (OCC) and Two-Phase Locking (2PL) for the following reasons. First, compared with
2PL, transactions running MVCC do not wait for other transactions to finish if conflict occurs. Instead, for read-write 
conflicts, transactions are able to time travel and locate an older version of the data item, while the resolution of 
write-write conflicts can be optionally postponed to commit time. Allowing multiple conflicting transactions to run in
parallel greatly increases the degree of paralellism of the system, and on today's multicore platform this feature prevents
processors from being putting into idle state frequently. Second, since MVCC does not employ any form of busy waiting
based on transactional reads and writes, no deadlock is ever possible