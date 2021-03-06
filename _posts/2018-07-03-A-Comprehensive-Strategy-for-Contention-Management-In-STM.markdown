---
layout: paper-summary
title:  "A Comprehensive Strategy for Contention Management in Software Transactional Memory"
date:   2018-07-03 21:12:00 -0500
categories: paper
paper_title: "A Comprehensive Strategy for Contention Management in Software Transactional Memory"
paper_link: https://dl.acm.org/citation.cfm?id=1504199
paper_keyword: STM; TL2; Contention Management
paper_year: PPoPP 2009
rw_set: Lock Table for Read; Hash Table with Vector for Write
htm_cd: Lazy
htm_cr: Lazy
version_mgmt: Hybrid
---

This paper proposes a contention management system that supports Software Transactional Memory with lazy acquire
and lazy version management. The system features not only a generally better contention management strategy, but
also enhances the base line STM with useful capabilities such as programmer-specified priority, irrevocable transaction,
conditional waiting, automatic priority elevation, and so on. 

Contention management is important for both eager and lazy STM designs. The goal of a contention management system is 
to avoid pathologies such as livelock and starvation, while maintaining low overhead and high throughput. Past researches
have mainly focused on policies of resolving conflicts when they are detected during any phase of execution. Among them, the 
Passive policy simply aborts the transaction that cannot proceed due to a locked item or incompatible timestamp; The 
Polite policy, on the other hand, commands transactions to spin for a while before they eventually abort the competitor,
which allows some conflicts to resolve themselves naturally; The Karma policy tracks the number of objects a transaction
has accessed before the conflict, and the one with fewer objects is aborted. This strategy minimizes wasted work locally.
The last is called Greedy, which features both visible read and early conflict detection. Transactions are also assigned
begin times. The transaction with earlier begin time is favored. Also note that due to the adoption of visible reads, the 
Greedy strategy incurs some overhead even if contention does not exist.

None of the above four contention management strategies works particularly well for all workloads and for all STM 
designs. In the paper the baseline is assumed to be a TL2 style, lazy conflict detection and lazy version management
STM. Each transaction is assigned a begin timestamp (bt) from a global timestamp counter before the first operation.
The begin timestamp determines the snapshot that the transaction is able to access, and is also used for validation.
Transactions are assigned commit timetamp (ct) from the same global counter using atomic fetch-and-increment after
a successful validation. Each data item has a write timestamp (wt) that stores the ct of the most recent transaction 
that has written to it, and a lock bit. The wt and the lock bit can be optionally stored together in a machine word. 
On transactional read operation, the wt of the data item is sampled before and after the data item itself is read. 
The read is considered as consistent if the versions in the two samples agree, and none of them is being locked. 
If this is not the case, then the transaction simply aborts, because an on-going commit will overwrite/has already 
overwritten the data item, making the snapshot at bt inconsistent. If the data item is in the write set, then the
read returns the updated item instead of performing a global read. On transactional write operation, the dirty value
is buffered at a local write set. The implementation of the write set can affect performance, as we shall discuss later.
On transaction commit, the protocol first locks all data items in the write set. If a lock has already been acquired 
by another transaction, then the current transaction will abort. Then validation proceeds by comparing the current wt
of data items in the write set with the bt. If any of them is greater than bt, then a violation has occurred, and 
transaction aborts. Otherwise, the ct is obtained, and dirty values in the write set are written back. Data items
are unlocked at the end of the transaction.

The original TL2 algorithm described above suffers from several prformance problems. The first problem is read 
forwarding, which happens when a dirty data item is read. The semantics of most STMs require that the read operation 
must return the dirty value. Since TL2 maintains versions in the write set lazily, the write log must be searched 
sequentially on *every* read operation (after optionally checking a bloom filter), which is both costly and pollutes 
the cache. This paper proposes using a hash table in addition to a linear log. The log can be traversed linearly
as usual during commit and write back, while the hash table provides shortcuts into the middle of the list to
accelerate item lookup. Note that the same problem does not exist in STMs using eager version management, because
the data item is updated in-place, and the metadata of the item is designed such that the owner of the item can be 
easily inferred.

The second problem that leads to sub-optimal performance is spurious aborts due to committed items. The dual timestamp scheme 
fixes the snapshot as the global state at bt, and tries to extend the snapshot to transaction commit at ct. The entire speculative
execution is based on the assumption that the snapshot at time bt will not change until ct, which suggests that any commit 
operation on the read set from bt to ct will trigger an abort. This, however, is overly restrictive, because what 
the speculative execution really needs is just a consistent snapshot, regardless of time. For example, let us assume a 
transaction starts at time bt, another transaction commits on data item X at (bt + 3), and then the transaction reads 
X in the read phase. According to the original TL2 algorithm, the transaction should abort as soon as it sees the wt
of X. This abort, however, can be avoided, if the transaction validates its past reads to see if they are still valid 
at (bt + 3). In the majority of cases, the validation should pass, which means that if the past reads are performed using
a begin timestamp equals (bt + 3), they should still observe exactly the same value. In the extensible timestamp design,
the transactin will then promote its begin timestamp to (bt + 3). If validation fails, then the transaction aborts,
because the snapshot is no longer valid at time (bt + 3). 

The last problem is unnecessary aborts due to locked items. Recall that the original TL2 aborts on a locked data item during
the read phase, and also when acquiring the write set during the validation phase. Aborting the transaction on a locked
data item during read is reasonable if extensible timestamp is not implemented, because a locked item indicates
that the wt of the item can be higher than current bt after the commit completes. With extensible timestamp, however,
since the transaction is able to adjust its bt to a higher value upon reading an item committed after it starts, 
it can simply wait for the commit to complete, and then load the updated value with a validation. Spinning on a lock
is usually frowned upon in STM designs, because they tend to waste cycles, and may introduce long waiting chains, or 
even deadlocks in the worst case. The paper argues that neither of these to applies here. First, transaction commit
is considered as a fast operation whose time is bounded. Waiting on transaction commit does not delay the read phase
beyond a reasonable amount. The OS scheduler can even be designed in a way such that committing transaction is given
high priority when making scheduling decisions to further reduce waiting time. Second, since reading transactions do
not hold any shared resource using locks, it is impossible for them to block other transactions. It is worth mentioning
that the same argument does not apply to the latter case, i.e. when transactions are acquiring its write set. This is 
because transactions hold locks on global resources during the validation phase. If they start to spin, a waiting chain or 
even deadlock can easily form, the consequence of which is disastrous.

The paper also presents an argument about livelock in the base system. Livelock occurs when two or more lock-holding 
transactions abort each other, and nobody can make progress. Note that a transaction during the read phase being aborted 
by a locked item does not constitute livelock, because progress is made by the committing transaction (the paper considers
this as livelock, though). The only two possibilities of livelock in the base system is: (1) Two lock holding transactions
abort each other during write set acquisition; and (2) Two lock holding transactions write into each other's read set
and then abort during validation. The first case is easy to resolve, as we can add an exponential backup as negative 
feedback. The second case is itself very rare, and can also be solved by backoffs. Overall, the base system presented 
in the paper is resistence to livelocks while being able to maintain a high throughput.

The paper then seeks to extend the base system to support comprehensive contention management. The contention management
scheme is based on priorities. Transactions of lower priority cannot commit if it will incur the abort of a higher priority
transaction in the future. Transactions of the same priority have equal chance as if they were normal transactions. Transactions 
by default have priority zero. At transaction begin, programmers could manually assign a positive priority to certain transactions. Transaction priority can also be elevated automatically by the system if it has been repeated aborted for several times.
In addition, a priority number of negative one is used to indicate conditional waits, a useful feature that blocks a 
reading transaction until the event it listens on (writes on the read set) happens. The highest priority is reserved
for irrevocable transactions, which is necessary if the transaction calls non-transactional library code and/or performs I/O
that cannot be easily made speculative. According to the definition, only one transaction is allowed to be in 
irrevocable state in the system. We cover in detail how these features are implemented in the following paragraphs.

In order to commit high priority transactions without being aborted by a low priority one, the read set of high
priority transactions must be made visible, such that low priority transactions could self-abort during validation.
All transactions with non-zero priorities (including negative priority), on transaction begin, must enter themselves into
an Active Transaction Table (ATT) using Compare-and-Swap (CAS). On transactional read operation, the high priority transaction
marks its read in a separate read table, which is essentially a lock table that has a bit for every ATT entry
for every data item in the system. Aliasing of data items is allowed by using a hash function to map data items to
read table entries. The transaction marks the corresponding bit of the lock table entry after computing the index 
of the read table entry. This is not needed for transactions with zero priority. If transactional reads or writes 
observe locked data items, high priority transaction always wait for the lock. At commit time after acquisition of the 
write set, the committing transaction, regardless of its priority, checks the size of the ATT. If table size is non-zero, 
then it begins forward validation against read sets of active transactions that have non-zero priority. The 
forward validation proceeds by hashing the write set into the read table, and check the priority of the transaction
if a bit is marked in the corresponding entry. If the transaction in the ATT has higher priority than the current one,
then the current transaction must abort, because otherwise it will write into the read set of a higher priority transaction.
Transactions in ATT remove themselves from the table and clears the bits in the read table when they complete.
Note that since conditionally waiting transactions are assigned negative priorities, they will not prevent any normal
transaction from committing.

As for conditional wait, the transaction first enters itself into ATT, and then marks its current read set in the read
table. A validation is also performed to avoid some other transactions committing on its read set after the 
conditional wait decision is made and before the transaction sleeps. Without the validation, it is possible that the 
condition is actually met during this interval, but the waiting transaction can never observe it. The transaction is then
blocked. At transaction commit phase, after performing write back and releasing all locks, the transaction scans the 
ATT, and finds if any conditionally waiting transaction is present. This action can be simplified using a counter to 
indicate the number of waiting transactions. The scan is only performed if the counter is non-zero. After finding a 
negative priority transaction, the committing transaction checks if its write set overlaps with the read set of the 
waiting transaction. The latter is awaken if two sets have a non-empty intersection.

Special care needs to be taken for the implementation of irrevocable transactions. First, there can only be one irrevocable 
transaction globally. This is implemented by having a dedicated ATT with only one entry. Transactions that failed to 
acquire the only entry can either wait or abort. Second, an irrevocable transaction must publish all its writes upon 
entering the irrevocable state, because external libraries can only read committed data. This can be achieved by locking
all data items in its write set and then performing a write back. This actually resembles eager version management, and 
works seamlessly with the base STM.