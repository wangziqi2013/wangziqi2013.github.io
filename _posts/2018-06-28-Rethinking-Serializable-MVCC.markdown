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
exceed the throughput of atomic operations on a single cache line. Second, SI is not guaranteed to be
fully serializable, as certain anomalies, such as write skew, could occur. Implementing Conflict Serializable 
(CSR) using MVCC is indeed possible, but then the validation phase validates the read set instead of the write 
set. The read set validation requires either marking the read when they are in the speculative read
phase, or checking all concurrent transaction's write set during validation. The first option does not 
scale, as read operations will write into global state. On many transactions, the size of the read set is 
orders of magnitude larger than the size of the write set. The second option is not viable if the degree
of concurrency is high, which is expected for a multicore in-memory database. The validating transaction needs
to spend significant number of cycles during the validation phase to perform set intersection.

This paper proposes BOHM, which takes advantage of pre-declared write sets of transactions to serialize 
them when they are submitted to the engine. The system features the following novel designs. First, the
concurrency control layer and the execution layer is fully decoupled. The execution layer does not perform
concurrency control, because concurrency has been planned prior to execution. Second, concurrency control and 
execution happens in separate stages. The lifetime of a transaction consists of two stages. In the first
stage, the transaction is serialized with other transactions by the concurrency control manager. All reads
and writes are planned according to the serialization order. In the second stage, the transaction is executed by
the execution engine. The execution threads does neither block on resources nor validate any speculative results.
They simply executes their own parts of the transaction from the beginning to the end, and output the result
to the external caller. Lastly, BOHM is scalable by using partition. The entire database is partitioned such that
each worker thread is responsible for a portion of the database, and it has exclusive ownership of all resources
attached to that portion. Threads at the same stage hardly need to communicate with each other. The only exception 
case where global synchronization takes place is when worker threads have finished processing a batch. A barrier is 
used to ensure threads finish the previous batch before the begin with the next batch.

BOHM works as follows. When a transaction is submitted to the system, it is required that the write set of the
transaction is declared. This is not always possible, especially if the transaction takes multiple "rounds" of 
communication between the engine and the application, using, for example, a cursor. BOHM does not intend to support 
transactions of this kind, and in the paper it is suggested that only stored procedure is supported. In the case
where the write set is unknown in advance, the database engine executes a speculative execution stage where no 
concurrency control is applied. The set of items that the transaction speculatively writes to are collected as the
write set. During the later execution phase, if the transaction writes to an item not in the speculative write set,
it must abort and retry. In the following text, we assume that transactions already have their write sets either 
declared by programmers or automatically generated via program analysis / speculative execution.

