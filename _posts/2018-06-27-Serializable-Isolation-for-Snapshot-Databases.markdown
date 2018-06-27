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
In MVCC, 