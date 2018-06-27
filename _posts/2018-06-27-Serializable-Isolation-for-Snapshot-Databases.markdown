---
layout: paper-summary
title:  "Serializable Isolation for Snapshot Databases"
date:   2018-06-27 01:11:00 -0500
categories: paper
paper_title: "Serializable Isolation for Snapshot Databases"
paper_link: https://dl.acm.org/citation.cfm?doid=1376616.1376690
paper_keyword: MVCC; SSI; Snapshot Isolation
paper_year: SIGMOD 2008
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

Multiversion Concurrency Control (MVCC) is a natural implementation of Snapshot Isolation (SI). Transactions
running under MVCC obtains a begin timestamp (bt) before they issue the first operation. For each read, they 
use the begin timestamp to access the data item with the maximum timestamp among those whose timestamps are 
smaller than the bt. For each write, transactions buffer the update in the local storage. Transactions obtain 
a commit timestamp (ct) from the same timestamp counter at the time of commit, and flushes its local versions, 
which are tagged with ct, to the global version chain. MVCC algorithm that implements SI does not check for 
read-write conflict before commit can take place. Instead, it checks whether two concurrent transactions intend 
to write to the same data item. If this happens, one of the two conflicting transactions must abort. Two broadly
accepted methods can be used to check write-write conflicts. The first method, which is the standard textbook 
procedure, checks the conflict at commit time. The committing transaction goes through the version chain for every 
item in its write set. A conflict is detected if a newer version has been created whose ct is between its bt and ct.
This is called "first committer wins", as write-write conflicts are only identified when the transactions that
performs the second write commits. The alternative method, called "first updater wins", does not wait for transaction 
commit for conflict detection. Transactions set write locks on data items when they pre-write, after checking that 
no concurrent writer exists. If another transaction writes a locked data item, then it indicates a potential write-write 
conflict if both writing transactions commit. In this case, the current transaction is blocked. If the other writer 
commits, then it is aborted. Otherwise the current transaction continues. In order to guarantee detection of all 
possible interleaving of conflicting writes, write locks are released after transaction commit or abort. 

Snapshot Isolation implemented using MVCC and "first committer/writer wins" rule prevents common fallacies of 
weaker isolation levels, such as non-repeatable read and lost update, from happening. This alone, however, is 
not sufficient for guaranteeing serializable transaction execution. One of the most well-known example is write skew,
where two transactions write non-overlapping data items in each other's read set. In this scenario, no write-write
conflict is detected, but the execution is non-serializable, because both transactions are logically before each other
via a write after read (WAR) dependency. 

This paper presents a concrete implementation of Serializable Snapshot Isolation (SSI) in Oracle Berkeley DB, a 
key-value relation database engine running MVCC. The concept of SSI is proposed in an earlier paper, which shows 
and proves the observation that certain "dangerous structure" in the dependency graph of SI may lead to non-serializable 
execution. The observation is based on the mechanism of reads and writes in MVCC. We present the proof as follows.
In MVCC, reads are processed using a begin timestamp, which always read committed data whose writing transaction
finishes before the reading transaction starts. Writes are locally buffered until the transaction commits, and any
interleaving commit operation in-between that writes on the current write set will cause the transaction to 
abort. The implication is that if WAR or WAW dependency even happens between transactions, then the two transactions 
must not overlap. The only case that transactions can overlap is WAR, where the writing transaction can commit before 
and after the reading transaction. Based on these properties of dependencies, let us assume there is a dependency cycle 
in the dependency graph, which is the sufficient and necessary condition of non-serializable execution. Let T3 be the 
transaction in the cycle that commits the earliest in real-time order, and the preceding transaction of T3 be T2.
T2 must be concurrent with T3, because otherwise it commits before T3 starts, or it starts after T3 commits. In the 
former case, the assumption that T3 commits the earlier is violated. In the latter case, T2 cannot precede T3 in
logical order. The only possible configuration is that T2 starts before T3 commits, and the dependency between them
is WAR. Similar reasoning can be applied between T1 and T2. We know T1 could not commit before T2 starts, because
otherwise T1 also commits before T3 commits. We also know T1 could not start after T2 commits, because otherwise 
T1 could not be logically before T2. The only sensible relation between T1 and T2 is that they are concurrent and 
T2 WAR depends on T1. 

The observation can therefore be stated as follows: An SI execution may lead to non-serializable result if two 
consecutive WAR dependencies exist in the dependency graph. The conclusion is that, in order to prevent non-serializable
execution, SI transaction scheduler should avoid any transaction from having an incoming and outgoing WAR dependency
at the same time. An MVCC scheduler that cohere to this rule is calld an SSI scheduler. Note that an SSI scheduler
can introduce false positives since not all dangerous structures will eventually end up as part of a cycle. Compared
with full dependency graph testing, which yields no false positive and no false negative, SSI has an obvious advantage
in terms of complexity and resource requirement. In the paper, it is claimed that SSI is not too complicated to implement 
on an existing MVCC engine, while being able to maintain high throughput and relatively low false abort rate.

SSI can be implemented as follows. A new type of lock, "SIREAD" lock, in introduced into the locking mechanism, which may
already exist due to the "first updater wins" rule. SIREAD locks do not block any other lock, and they serve merely as 
a signal to notify other transactions of a concurrent read operation. Each transaction has two boolean flags, one "SSI-IN"
which indicates it is the destination of WAR, another "SSI-OUT" which indicates it is the source of WAR. Threads acquire 
SIREAD locks before they access data items. If a write lock is already set, then the reading transactions marks the SSI-OUT
flag of itself and SSI-IN of the concurrent writer because it knows the concurrent writer has already written to the item. 
The current transaction must be reading a version earlier than the uncommitted version, constituting a WAR. After the read,
it performs a second check for newer versions that are created by transactions before it sets the read lock. These versions
might be created by active or already committed transactions. In the latter case, if the committed transaction has its SSI-OUT
set, then the current transaction cannot not help but just self-abort. On write, transactions create new versions after 
acquiring the write lock. If a SIREAD lock is detected, the writing transaction sets the SSI-OUT for owners of the SIREAD
lock, and SSI-IN for itself. Care must be taken if owners have committed, in which case if they also have SSI-IN set,
the writing transaction cannot help but self-abort. On transaction commit, if both SSI-IN and SSI-OUT flags are set,
the transaction must abort.

One particular detail that is worth mentioning is that SSI scheduler requires transactions to retain part of their 
states even after they commit. In the above description, two SSI flags for detecting WAR pairs are checked even
after the transaction has committed. In addition, the SIREAD lock cannot be relased after transaction commits,
because write operation can well be performed after the reader has committed, but yet still results in a dangerous 
structure. Proper garbage collection mechanisms 