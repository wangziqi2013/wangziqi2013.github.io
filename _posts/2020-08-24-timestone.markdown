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

**Highlight:**

1. TimeStone is essentially redo log + DRAM Buffer + group commit + operation logging. Group commit amortizes persistence 
   cost by combining multiple object updates into one and let the traffic be absorbed by DRAM. Operation logging works 
   with group commit to allow transactions to commit immediately, since the txn can be recovered using the operation log.

**Questions**

1. How does each transaction find the volatile object in the write set? Is there a per-thread mapping table that maps the 
   object's master address to its local write set address?

2. Operation logging only works if re-execution has exactly the same semantics as the original execution. This is difficult
   to guarantee, especially if the arguments are also objects with pointers, or allocated on the stack, or library environments
   cannot be recovered.

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
Each thread also maintains a local write set as volatile log, called the transient version log, or TLog. Allocation of 
write set objects is performed on the TLog, which will be reclaimed by GC, which we discuss later. 
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

The second design aspect of TimeStone is the persistency model, which determines when and where objects are stored. 
As discussed previously, TimeStone maintains several copies of the same object for different purposes. There are four
types of object copies, with two of them being volatile, and the other two being non-volatile. The first type is
the private object in the local write set, which is allocated on the per-thread log, which will be linked into the 
version chain on transaction commit, turning into the second type. The second type is the object that can
be accessed by other threads after transaction commit. These objects remain volatile, which will be "checkpointed"
on garbage collection to the NVM. Note that one of the unique features of TimeStone is that the transaction is 
fully committed logically after the commit point, which does not depend on whether the second type objects are persisted 
to the NVM. Those not persisted will be recovered by re-executing the transaction body, as we will see later.
The third type object are those that have been persisted to the NVM into another log, called the Checkpoint Log (CLog),
which stores "compressed" version from the TLog. While multiple objects from the TLog can exist in the version chain, 
CLog objects must always be the least recent or the least few recent objects in the version chain, since they are 
generated by persisting the newest version from a version chain and discarding the rest during GC.
The last type of object is the master object, which is allocated from the non-volatile heap. Master objects store the 
least up-to-date data, which serve as the last resort of version lookup, if all TLog and CLog objects cannot satisfy
a read access.

Master objects are the handle for accessing all copies of the same object. Application programmers must use a wrapper
to declare a master object type. The wrapper adds a few extra fields to the master object: A lock word, a pointer to
the volatile version chain, and a pointer to the checkpointed object.
To reduce NVM accesses, the master object header is allocated on the DRAM. If a header does not yet exist when the master
object is accessed, indicating no extra copies exists, a headrer is allocated from the DRAM first, with all fields 
initialized to NULL.

A TLog object is copied to the NVM and becomes a CLog object during TLog garbage collection. The GC process is similar
to group commit, in which dirty data from multiple transactions are persisted in a batch. Group commits are used to increase
the chance of write combining and improve write locality for amortizing I/O over several transactions, at the cost
of larger transaction latency. TimeStone, however, leverages group commit to absort object writes with the volatile TLog.
Recall that committed objects are always allocated on the TLog first, and linked into the version chain on transaction 
commit. If an object is written multiple times between two GC invocations, only the most recent version needs to be 
persisted, reducing write amplification. To avoid losing data after transaction commit, TimeStone also maintains an
operation log, OLog, which contains the function pointer and arguments of the transaction instance. TimeStone assumes
that transactions can be replayed by executing the function pointer with the given arguments on crash recovery.
On transaction commit, the function pointe of the transaction, together with arguments, are persisted to the OLog,
which serves as the logical commit point of the transaction. As long as the OLog entry is fully persisted, the 
transaction is considered as committed, which can be recovered by re-execution.

TimeStone maintains a global timestamp, ckpt-ts, which represents the last commit timestamp of objects that have been
group committed to the NVM. Transactions whose commit timestamps are from ckpt-ts to the current global counter are 
considered as committed, but not persisted, and will be group committed to the NVM during GC.
GC follows the two following rules. First, for a volatile version chain, all versions except the most up-to-date
version are discarded, since they have been overwritten by newer versions. For those non-up-to-date versions, they
are safe to be freed from the log after one grace period, in which all threads experience at least one transaction 
termination since the commit timestamp of the up-to-date version, or are not executing any transaction. The grace 
peroid ensures that no transaction can ever hold a reference to old versions after the new version has been committed.
For the most up-to-date version, it is copied to the non-volatile Tlog, and then the pointer in the object header
is changed, such that the version chain pointer is set to NULL, and the checkpoint object pointer is updated to the 
TLog entry. After one more grace period since the header update, the most up-to-date object in the version chain
can also be removed, since no thread could ever hold a reference to that object.

In practice, the GC thread linearly scans the TLog of all threads. For each object in the log, the thread first checks
whether it is the most up-to-date object. If true, the object is checkpointed to the TLog, and the thread waits for two
grace periods since the current global timestamp value after the persistence operation. Non-up-to-date versions are 
simply skipped, and reclaimed after the two grace periods. The ckpt-ts is updated to the minimum commit timestamp
among all committed volatile objects after this process. 

The CLog, as a redo log, also needs to be periodically copied back to the master object. The GC process is similar to
TLog GC. The background thread scans objects in the log. For each entry, if it is not the most up-to-date checkpoint
object, which can be checked by comparing the pointer in the master's header with the log entry's address, it is 
simply skipped. For the most up-to-date object, it is copied back to the master object, and all checkpoint objects 
on the same addresses are reclaimed after two grace periods. 

The OLog is GC'ed when the ckpt-ts is updated. All entries whose commit timestamps are before the ckpt-ts can be reclaimed,
since the working sets of these instances have been persisted to the NVM.

On recovery, the handler first searches the OLog for valid entries, which will then be replayed serially based on their
commit timestamp order, as the MVCC algorithm commits transactions in the logical commit order. After re-executing 
transactions that have been logically committed but not yet persisted, the handler then copies all entries from the CLog
to the master copy. Only the most recent ones are copied, with the rest discarded. No grace period is needed after copying
an object, since there would be no parallel threads.

TimeStone also supports three isolation levels: Snapshot Isolation (SI), serializable, and linearizable. In SI mode, no
read validation is performed, and write-write conflicts are detected with per-object locks. In serializable mode, transactions
execute with version chain traversal, and performs read validation on commit. In linearizable mode, transactions not only
perform read validation, but also must always access the most recent versions, i.e., the transaction must not time-travel
to read a past version, since in this case the logical commit point of the transaction will not lie within the real-time
execution period, which violates linearizability.
