---
layout: paper-summary
title:  "Rethinking serializable multiversion concurrency control"
date:   2018-06-28 16:29:00 -0500
categories: paper
paper_title: "Rethinking serializable multiversion concurrency control"
paper_link: https://dl.acm.org/citation.cfm?id=2809981
paper_keyword: MVCC; Serializable; BOHM
paper_year: VLDB 2015
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

Multiversion Concurrency Control (MVCC) is a natural way of implementing Snapshot Isolation (SI),
because taking snapshots at the beginning of a transaction is almost free. Transactions acquire
a begin timestamp (bt) before they perform the first operation, and optionally also acquire a 
commit timestamp (ct) after the last operation in order to commit. Read operations take place 
by traversing the version chain of the data item and reading the version that is visible to the
current bt. Write operations are performed by locally buffer the updated value until commit time.
At commit time, transactions perform validation before they can proceed to the write phase.
For snapshot isolation MVCC, transactions validate by checking whether items in their write set
have been updated by a concurrent transaction. If this is the case, then a write-write conflict is
detected, and the committing transaction must abort. Otherwise, the transaction installs its locally
buffered write set onto the version chain and commits successfully.

Both SI itself and the implementation of SI using MVCC are problematic on modern multicore platform.
The paper identifies two problems that can affect performance as well as scalability. First, timestamp
allocation is commonly implemented using a centralized global counter. Transactions must atomically
increment the counter when it acquires the timestamp. Frequently incrementing the counter will
incur excessive cache line traffic, which causes long latency for other memory operations on the 
communication network, and can itself become a bottleneck. The throughput of transactions can never
exceed the throughput of atomic operations on a single cache line. 