---
layout: paper-summary
title:  "Concurrency Control in Database Systems: A Step Towards the Integration of Optimistic Methods and Locking"
date:   2018-04-04 16:17:00 -0500
categories: paper
paper_title: "Concurrency Control in Database Systems: A Step Towards the Integration of Optimistic Methods and Locking"
paper_link: https://dl.acm.org/citation.cfm?id=809759
paper_keyword: OCC; 2PL; Hybrid
paper_year: 1981
rw_set: Set
htm_cd: Both Eager and Lazy
htm_cr: Both Eager and Lazy
version_mgmt: Both Eager and Lazy
---

This paper proposes a concurrency control manager that uses OCC and 2PL. 
The motivation for the integrated approach is based on observations as follows.
Two-Phase Locking (2PL) guarantees progress of transactions in the absence of deadlock,
but suffers from high locking overhead especially for small transactions.
On the contrary, classical OCC with backward validation (BOCC) has low locking overhead, but
the chances that transactions are forced to abort in validation phase increases for long 
transactions, as more write sets of committed transactions are tested for non-empty
intersection. If conflicts occur frequently, long transactions can never commit,
causing the starvation problem.

One simple but irrelevant technique can be used to slightly improve the throughput of set
intersection based BOCC. During the validation phase, classical BOCC intersects the read 
set of the validating transaction with committed transactions during its read phase, and 
aborts the validating transaction on non-empty intersections. This is an overkill, because
not all overlaps of read and write phase will result in non-serializable schedules. One example
is given below:

**Serializable Non-OCC Schedule Example:**
{% highlight C %}
   Txn 1         Txn 2
   Begin
  Read  C
              Begin Commit
                Write A
                Write B
                Finish 
  Read  A
  Read  B
Begin Commit
  Write A
  Write B
  Finish
{% endhighlight %}

Since transaction 2 begins commit after transaction 1 begins read phase, transaction 1 will intersect its read set
which contains A and B with transaction 2's write set, which contains A and B also. The non-empty
intersection indicates that transaction 1 should abort. The schedule, however, is serializable, with
transaction 1 serialized after transaction 2.

The above example reveals an important defect of set-intersection based BOCC: by reading the value of the global 
timestamp counter only before the first read operation during the read phase, all later read operations are
considered by the validation phase as taking place at exactly the same time as the timestamp is read.
This is because the begin timestamp (bt) is compared with the commit timestamp (ct) of committing transactions to 
determine the appropriate order of reads and writes. In this example, since transaction 1 takes bt
before transaction 2 takes ct, all its reads are considered as being performed before transaction 2
committing its write set. If the actual order differs from this perspective, then validation would fail.

Instead of only reading the global timestamp counter before the first read as the global read bt, this
paper proposes that every read is preceded by a read to the global timestamp counter, and the value is 
kept in the read set as the read timestamp (rt) of the data item. On backward validation, if for a committed transaction, 
the read set of the validating transaction has an non-empty overlap with the committed transaction, 
the rt of these data items in the intersection are checked against the committed transaction's ct. If
all these rt are greater than the ct, then the schedule is still serializable. This is because although 
the read phase of the validating transaction overlaps with the write phase of the committed transaction,
such overlap is "benevolent", as the serialization order is sustained by having these read 
operations happening after the write operation. Schedules like the example above can commit successfully
in this case, because both data items A and B have a greather rt than transaction 2's ct, and thus
validation succeeds.

The rest of the paper talks about combining 2PL and OCC into one concurrency control manager, such that
short transactions are executed under OCC mode for the first few runs, and if the number of failures 
exceeds a thereshold, it is switched to 2PL mode, and runs pessimistically by taking locks. Long 
transactions can be marked beforehand, and are always executed in 2PL mode.

Two important assumptions are made in this paper. The first assumption is that 2PL also follows
the read-validate-write pattern, albeit the validation phase does nothing. The crux here is that 
data items are not written in-place even if a write lock has been taken. This helps concurrent OCC
transactions avoid reading inconsistent values. The second assumptions is that validation and write phases
are performed in a global critical section. Furthermore, if the critical section is currently 
occupied, no read lock can be granted to avoid read-write races between 2PL transactions and the 
validating transaction. Write locks can be granted concurrently, as data items are only modified
in the critical section even for 2PL transactions.

During the read phase, both 2PL and OCC transaction read data items, and add them into the read
set (for OCC) or read lock set (for 2PL). Similarly, written data items are added into the write set. 
For 2PL transactions, read and write locks are acquired
correspondingly as it accesses data items. Modifications to data items are buffered locally. 
On validation, transactions first enter the critical section. 2PL transactions does nothing, 
and is hence guaranteed to commit as long as they are not involved in deadlocks. 
An OCC transaction first validates its read set with the write set of all committed transactions, no matter
2PL or OCC. Then, it performs a forward validation that is similar to FOCC: for all active 2PL transactions,
it intersects their read sets with its write set. On any non-empty intersection, the validating OCC
transaction aborts. After validation, the write phase is entered, and transactions write back their
dirty values, before they exit the critical section. 

Note that during the FOCC validation phase, if the acquisition of read locks are not blocked, then
the following non-serializable schedule can happen:

**Non-serializable FOCC Example:**
{% highlight C %}
    2PL           OCC
   Txn 1         Txn 2
   Begin
  Read  C
              Begin Commit
               Validation
  Read  A
  Read  B
                Write A
                Write B
                Finish 
Begin Commit
  Write A
  Write B
  Finish
{% endhighlight %}

In the above example, transaction 1 runs in 2PL mode while transaction 2 runs in OCC mode.
Transaction 2 begins commit by first validating its write set which contains A and B against
the read set of transaction 1. The validation succeeds because at that time transaction 1's 
read set only contains C. Transaction 2 then enters write phase, and writes back A and B.
Before these writes are actually performed, transaction 1 acquires read locks for A and B,
and reads their values. When transaction 1 commits, it also writes A and B. 
This example is non-serializable, because by reaing the old values of A and B, transaction 1
is serialized before transaction 2. During the write phase, however, transaction 1 is 
serialized after transaction 2 by writing A and B.

If read lock requests are blocked between the validation phase and write phase of 
OCC transaction 2, then no read can ever be performed between it validates and writes
back. All read operations to data items in transaction 2's write set must either 
take place before the validation, which causes transaction 2 to abort, or 
they must be delayed after the write phase, which serializes correctly.

In addition to "pure" 2PL and OCC modes, a more hybrid OL (Optimistic + Locking, not optimistic locking) 
mode can be adopted. The OL mode is valuable to transactions that access independent items for most of times,
but also access a few hot data items that are prone to invalidation and frequent conflicts. In this case,
two different treatments can be applied simultaneously in one transaction: For those items that are expected
to be cold, we use OCC for maximum throughput; for those that are hot, 2PL is used to avoid frequent aborts
after an optimistic read.

The validation phase changes accordingly with OL mode as follows. For 2PL transactions, validation still does
nothing. For OCC transactions, in addition to testing its write set against all active 2PL transactions, 
the write set of all active OL transactions are also tested. Validation for OL transactions is similar to
the validation for OCC transactions, except that we only test the optimistic part, i.e. for committed
transactions, the OL transaction only tests its unlocked read against their write sets; For all active
2PL and OL transactions, the OL transaction only tests its unlocked write against their read sets.

The last section of the paper looses the constraints that read locks cannot be granted during validation
a little bit. Actually, as long as the data item being requested is not in the write set of the current committing 
transaction, the read lock can be granted. The CC manager just needs to check the incoming read lock request
against the write set of the committing transaction.