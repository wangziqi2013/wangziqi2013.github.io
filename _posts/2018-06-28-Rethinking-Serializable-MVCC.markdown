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

One of the most important of BOHM is that when a transaction is submitted to the system, the write set of the
transaction must be declared. This is not always possible, especially if the transaction takes multiple "rounds" of 
communication between the engine and the application, using, for example, a cursor. BOHM does not intend to support 
transactions of this kind, and in the paper it is suggested that only stored procedure is supported. In the case
where the write set is unknown in advance, the database engine executes a speculative execution stage where no 
concurrency control is applied. The set of items that the transaction speculatively writes to are collected as the
write set. During the later execution phase, if the transaction writes to an item not in the speculative write set,
it must abort and retry. In the following text, we assume that transactions already have their write sets either 
declared by programmers or automatically generated via program analysis / speculative execution.

BOHM works as follows. When the transaction is submitted to the concurrency control manager, a single thread 
adds the transaction into a global queue. The global queue serializes all transactions in the order that they
are enqueued. Since only one thread maintains the queue, no contention would occur during this phase, and transactions 
always have a well-defined order with regard to all other transactions. The timestamps of transactions are implicitly
assigned as their positions in the queue. BOHM's timestamp assignment process differs from the base line algorithm
described earlier as it only assigns one timestamp instead of two, one for begin and another for commit. By
assigning only one timestamp to each transaction, transactions logically happen at a single point of time, and thus 
no validation againt concurrenct transactions between the bt and ct is needed.

In the next stage, worker threads dequeues transactions from the global queue, and plans transactional reads and writes
serially. Transactions are processed by multiple worker threads, each being reponsible for a partition of the database. Worker 
threads process transactions in the order they are dequeued from the global queue, and hence the serialization order of 
transactions is observed in this stage. Transactional writes are serialized by scanning the write set of the transaction, 
and insering placeholders into the version chain as contains for updated data generated during the execution phase. Transactional
reads cannot be serialized at this stage, because they remain unknown until the execution phase. Each placeholder is tagged 
with the timestamp of the transaction that generates it for read lookup as the create timestamp. If a placeholder is overwritten 
by a write from a more recent transaction, then the timestamp of the more recent transaction is also stored in the old placeholder
as the end timestamp. The identity of the transaction that generates this version is also stored in the placeholder in order 
to resolve RAW dependencies at run-time. As an optimization, if the read set of transactions is pre-declared prior to execution,
they can also be serialized at this stage. Read sets are also scanned, and the pointer to the version or placeholder at the top 
of the version chain when the transaction is being processed is stored. No version lookup is needed if read sets are serialized 
at this stage, because transactions are always processed in the serialization order. Later on during execution, if the read set 
has been serialized, the execution engine does not peform any read lookup, but instad just use the pointer to the version or 
placeholder to process reads. This optimization can be enabled on a per-transaction level, and needs no global change.

The planning stage is supposed to run fast for several reasons. First, transactions are processed by several independent 
worker threads, the communication between which is rare. Each worker thread simply takes a reference to the transaction in
the global queue, and scans its write set (and read set, if applicable) while inserting placeholders into the version chain.
Since the database is partitioned, and worker threads only insert into their own partition, contention is supposed to be low.
Increasing the number of worker threads can also increase the throughput of transaction planning, because the amount of work 
each worker thread is responsible for decreases. It is also noted by the paper that the process we present here is an example of 
intra-transaction parallelism.

To reduce synchronization overhead, worker threads do not synchronize and wait for each other to finish processing one transaction
before they can start the next. Instead, transaction planning are performed in a batch of transactions. Worker threads do not have 
to keep lockstep and be on the same transaction at all times. In fact, it makes no harm if a few transactions are way ahead of others 
or are lagging behind, since worker threads only process their own partition of the database. A global barrier is only needed after 
the current batch has finished, and worker threads wait for each other to finish before they can begin with the next batch. 

In the next stage, the execution stage, transactions are executed by the execution engine, which sends read and write requests 
to the MVCC engine. The execution engine consists of another set of worker threads, each being responsible for executing the 
logic of one transaction in the batch from the planning stage. In contract to the intra-transaction parallelism the system
demonstrates in the planning stage, in the execution stage, worker threads exploit inter-transaction parallelism and 
execute the transactions in a batch in parallel. The execution does not need concurrency control, because write operations 
have been ordered in the planning stage, and read operations could find the corresponding version using the timestamp and 
the version chain. The only problematic case is RAW dependency, because the value cannot be consumed before it is produced
by another worker thread. If a worker thread intends to read a version, but unfortunately the data has not been generated yet,
the thread suspends the current transaction, and recursively executes the source transaction if it is not being executed. 
Note that the execution stage and the planning stage work on different batches at any given time. There would be no race condition
between the two stages. 

Garbage collection (GC) has always been an indispensable part of MVCC systems. The high level goal of GC in MVCC is to 
delete versions that can no longer be observed by any active transaction. Performing GC in a fine guanularity usually
incurs high overhead. In BOHM, GC takes advantage of the fact that all transactions in an earlier batch also logically
happen before all transactions in a later batch. If a version v<sub>j</sub> is overwritten by batch b<sub>i</sub>, then 
all versions smaller than v<sub>j</sub> can be garbage collected after batch b<sub>i</sub> is finished. To achieve this,
each worker thread k maintains a thread local variable batch<sub>k</sub> which stores the minimum batch it has finished 
processing. A global low watermark is periodically updated by taking the minimum of all batch<sub>k</sub>. Versions
are then collected if they have been overwritten by transactions in batch or batches higher than the global low watermark.