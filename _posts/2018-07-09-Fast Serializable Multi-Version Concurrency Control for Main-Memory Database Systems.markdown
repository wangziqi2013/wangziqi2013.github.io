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

In practice, MVCC is favored by commercial database vendors over other concurrency control schemes such as Optimistic 
Concurrency Control (OCC) and Two-Phase Locking (2PL) for the following reasons. First, compared with 2PL, transactions 
running MVCC do not wait for other transactions to finish if conflict occurs. Instead, for read-write conflicts, 
transactions are able to time travel and locate an older version of the data item, while the resolution of write-write 
conflicts can be optionally postponed to commit time. Allowing multiple conflicting transactions to run in parallel 
greatly increases the degree of paralellism of the system, and on today's multicore platform this feature prevents
processors from being putting into idle state frequently. Second, since MVCC does not employ any form of busy waiting
during the execution phase, no deadlock is ever possible, and therefore, deadlock detection or prevention mechanism
does not have to be implemented. Third, modern architecture generally discourage lock-based synchronization unless
necessary, as it incurs huge amount of cache coherence traffic on the communication network. Excessive coherence traffic
not only delays lock and unlock operations themselves, but also affect the delivery of normal memory operations, which
slows down the entire system. In the case of 2PL, contentions are created by the centralized lock manager, which is 
often implemented as a monolithic object that is shared among all processors. In contrast, in MVCC, versions are managed
in a distributed way, and contention occurs only if certain data items become "hot spots". Finally, compared with OCC,
MVCC supports read-only transaction better by maintaining multiple versions. Unlike OCC, in which reading transactions must
abort if the data item has been overwritten by another transaction before it can be consumed, MVCC allows the 
reading transaction to lookup the version chain and locate the correct version it hopes to access, reducing conflict aborts. 

Despite the advantages enumerated above, MVCC can suffer from several problems if not implemented properly. First, in some
products, data table is implemented as an array of pointers pointing to the version chain of each row. Compared with the 
storage scheme of non-MVCC systems, the extra level of indirection can degrade scan performance, because each version
access involves at least one pointer dereference. Second, when the read set is large, read validation can become costly,
because the time required for validation is propotional to the number of items in the read set. In OLAP environments where
table scan is not as infrquent as in OLTP, and where transactions usually read a large portion of the table, these two 
combined will slow down both the read phase and the validation phase, negatively affecting the throughput of the system. 

This paper proposes an innovative MVCC design that alleviates the two problems mentioned above. First, the most recent 
version of data items are always stored in a contiguous chunk of memory, using columnar storage. This ensures that table 
scan can be really fast as long as no older version is being read, as the regular access pattern benefits from both spatial
locality and hardware pre-fetching. In the case that transactions need to "time travel" to an older version, they read 
the head pointer stored in an invisible column of the table, and traverses the version chain. The version chain is implemented
as delta storage, i.e. each version stores the difference ("delta") between the current version and the next younger 
version. Each node in the version chain is tagged with the commit timestamp of the transaction that created it. Assuming no 
uncommitted write is present (we deal with writes later), in order to reconstruct a particular version given the begin timesamp, 
the read procedure first reads the most recent version, and then iterates through the version chain until it finds a version 
whose commit timestamp strictly less than the begin timestamp. For each node in the version chain, the delta is applied 
to the data item. Since delta is stored in its raw form (i.e. binary difference), the delta replay is very fast as it 
only involves copying memory into local storage. Note that if the reading transaction already wrote to the data item, 
then the operation should return the value it has written instead of the one obtained by replaying the delta chain. 

Write operations are processed in a more complicated way. On transactional writes, the transaction first creates an invisible
version on the version chain of the data item. The uncommitted version is tagged with a special "transaction ID", which is 
higher than all possible begin and commit timestamps. In practice, the system uses a 64 bit integer as timestamps, where bit 
0 - 62 are dedicated to the value of the counter, and bit 63, the highest bit, distinguishes begin/commit timestamps from
transaction IDs. If bit 63 is set, then other transactions traversing the version chain knows that the in-place version 
belongs to an uncommitted transaction, and will ignore the in-place value. The uncommitted version stores the delta between 
the version before update happens and the updated version. Similar to the "first updater wins" rule used by OracleDB, if
there is already an uncommitted version at the head of the version chain, the writing transaction must abort, because we 
are unable to resolve uncommitted write-write conflicts. In the meantime, the writing transaction adds the delta which 
contains the before-image of the data item under modification into a private undo log. Undo logs are archived with the 
commit timestamp of the transaction after it commits.As we shall see later, the undo log is the central component for 
implementing efficient validation. 

On transaction commit, the transaction validates its read set to make sure no write operation happened during its execution.
The validation is carried out using predicates instead of checking each individual data item in the read set. One of the most
fundamental assumptions about the MVCC system is that data must be read via predicates. Predicates are specified using 
the "WHERE" clause of SQL statements, and can be translated to either point query or table/index scan depending on the 
semantics. Predicates that are used to access data items are logged during the execution of the transactions. At validation
time, the system assembles all predicates in the log into a predicate tree. The nodes of the tree are logic expressions on a single
attribute of the table. Parent-child edge represents "AND" relation, while sibling nodes are connected using "OR". Overall,
the predicate tree maps tuples to boolean values, and is a union of all predicates used for accessing data items. Any tuple
that would have been selected by those predicates will return true from the tree. After building the predicate tree, the 
validating transaction then enumerates the undo logs of transactions that committed during its execution using their commit 
timestamps and the current begin timestamp. The transaction then tests each before-image in the undo log against the 
predicate tree. If any of the entries in the undo log returns true, then it is an indication that one of the writing 
transaction has written onto the read set of the current transaction, and the current transaction must abort. 

After a successful validation, the transaction obtains its commit timestamp by atomically fetch-and-incrementing the 
global counter. It then writes the commit timestamp into all uncommitted versions in the write set. The commit completes
after all versions are made public and the undo log is archived with the commit timestamp.

As mentioned earlier, scan performance is critical for OLAP workloads where the read set is usually large and scan
is the dominant type of workload. In the database system, Hyper, where the MVCC described above is deployed, scan
operations are accelerated using Just-In-Time compilation with LLVM. The advantage of storing the most up-to-date version
in the data table is that the compiled assembly for scanning the table is shorter, as most of the entries in the 
table does not have any version chain. The machine code can therefore omit checking for old version most of the time 
when there is no version chain. To support this, the data table is divided into several partitions, each of 1024 rows.
A descriptor is associated with the table, which describes the range where versions must be checked. When generating
code for performing scans on a partition, the generator loads the descriptor of the partition, and only generates logic
to check versions for items in the range. This way, scan can be efficiently compiled Just-In-Time without having to pay 
the extra overhead of loading and branching.