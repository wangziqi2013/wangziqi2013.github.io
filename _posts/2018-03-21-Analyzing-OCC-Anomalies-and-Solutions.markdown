---
layout: post
title:  "Analyzing Optimistic Concurrency Control Anomalies and Solutions"
date:   2018-03-20 21:47:00 -0500
categories: article
ontop: true
---

### Introduction

Optimistic Concurrency Control (OCC) are drawing more and more attention as multicore
has become the mainstream platform for today's database management systems and transaction
processing systems. Compared with Two Phase Locking (2PL), OCC algorithms are expected to 
expose better degree of parallelism due to the wait-free read phase and relatively short 
validation and/or write phases that may require critical sections and/or fine grained locking.
One of the difficulties of designing efficient OCC algorithms, however, is to reason about complicated
read-write ordering issues due to the speculative and optimistic nature of OCC executions.
In this article, we discuss a few race conditions that are typical to OCC. For each race 
condition, we propose several solutions to avoid them. We also point out cases where OCC
may raise "false alarms" to indicate violations, but which are actually serializable. 
We hope our discussion could aid algorithm engineers to prevent common fallacies, while 
still keeping their designs efficient. 

### Racing Read and Write Phases

Conflicting read and write phases is the most common form of races in OCC. If the write phase
starts after the reading transaction began, and writes into data items that are also in the
reading transaction's read set, then non-serializable schedules can occur in the form of
RAW and WAR dependency cycles, as shown below.

**Racing Read and Write Phases Example:**
{% highlight C %}
   Txn 1         Txn 2
   Begin 
  Read  A
              Begin Commit
                Write A
                Write B
                Finish
  Read  B
   ....
{% endhighlight %}

Note that in this article, we deliberately make a distinction between the two 
possibilities where the committing transaction enters write phase *after* the other transaction begins read
phase, and the opposite. This is because they require different solutions to deal with. In this section,
only the former case is addressed. 

In the given example, transaction 2 begins its write phase after transaction 1 begins 
read phase. They collide on data items A and B. If we take into consideration the logical 
serialization order of OCC, which is usually the order that transaction finishes validation, it is obvious that 
transaction 1 performs the read operation "too early". When transaction 2 decides to commit,
it is serialized before transaction 1. Transaction 1's first read operation, therefore, must actually
return the updated value of A. Failing to observe this order will result in violations, as indicated by our example.

A few techniques can be applied to prevent the race condition. The essence of the solution is to detect write 
operations by committing transactions on data items that the reading transaction has accessed. As the 
reading transaction must be serialized after concurrent writing transactions who have already made commit deicisions,
any overwrite of values in its read set would indicate a commit order violation. Detecting these violating writes 
requires some post-read validation of the read set. In the following discussion, we assume serialized validation and write 
phases. Concurrent commits is possible, but is discussed in a separate section.

In the classical Backward OCC (BOCC) design, the validation is conducted by having reader transactions remember 
committed transactions during its read phase. On validation, the read set of the transaction and write sets from 
committed write phases are tested for non-empty intersections. Tracking committing transactions during the read 
phase can be achieved by using a timestamp counter. The counter is incremented when a transaction completes the 
write phase, and tagges its write set with the value of the counter after the increment. Meanwhile, transactions 
in the read phase read the counter before the first read operation and after it enters validation. Write sets whose 
tags are between this two timestamps are obliged to be checked. 

An alternative approach is to have committing transactions broadcast their commit decisions together with a reference 
to its write set to all reader transactions, validating in the forward direction (Forward OCC, FOCC). 
A reader transaction receiving the broadcast first checks its current read set against the broadcasted write set,
and can optionally abort early on a non-empty intersection. Reader transactions also needs to buffer the 
broadcast. They either test every single read operation with all write sets, or perform a bulk validation
after the read phase. Any hit or non-empty intersection indicates a possibly "early read", and will cause an abort. 

We use BOCC and FOCC as a starting point to demonstrate what OCC algorithms should validate in general. BOCC and FOCC
with serial validation do not allow races that are detrimental to correctness. 
In the following discussion, however, as we introduce fine grained version-based validation and parallel commits, 
we shall see that some races are common design fallacies if the algorithm is not verified carefully. 

Fine grained per-element version-based validation can reduce validation overhead 
at the cost of metadata storage for each individual data items. In this scheme, a write timestamp (wt) is associated
with every individual data item, which records the commit timestamp of the most recent transaction that wrote into
the data item. A dual timestamp strategy is employed to detect "early read" races. On transaction begin, a begin
timestamp (bt) is obtained from the global timestamp counter by reading its value. Correspondingly, on transaction
commit, the commit timestamp (ct) is obtained by atomically incrementing the global timestamp counter. The wt of data 
items in the committing transaction's write set will be updated to ct during the write phase. Note that validation
and write phases are serialized. On validation, if for some data item X, its current wt is greater than bt,
then it must be the case that another committing transaction obtained ct and updated X after the validating 
transaction had obtained bt. Clearly, a violation may have occurred, and the validating transaction must abort.

Postponing all validations till commit time, i.e. "lazy conflict detection", has certain advantages. 
In this article, we do not perform detailed analysis on algorithmic characteristics of different OCC schcmes. 
The problem of delaying conflict detection is that the speculative read phase may read inconsistent values 
that can never occur during a serial execution. Such temporary unholy state can sometimes be fatal, because the program 
may trigger spurious page access violation, or never terminate. Sandboxing is generally required to monitor the state of the 
transaction. On the event of segment fault or suspected dead loop, the transaction must be restarted.

Performing read validation for the current read set on every speculative read can avoid the problem. This incremental 
validation scheme has an unacceptable overhead of O(n^2) where n is the number of read operations. Programmers can 
specify in the transaction code whether a speculative read may lead to undefined behavior should inconsistency occurs. 
The OCC runtime then only performs read validation on selected reads. To further reduce the overhead,
the OCC runtime can compare the transaction's bt with the current global timestamp counter after read is performed
and before incremental validation is invoked. If the two timestamps agree, then validation is skipped, because no 
other transaction has ever committed, and no data item can be possibly updated since transaction begin.

There are schedules, however, that OCC does not accept, but are actually serializable. We give one in the example below: 

**Serializable Non-OCC Schedule Example 1:**
{% highlight C %}
   Txn 1         Txn 2
   Begin 
  Read  A
                 Begin
                Read  A
                Read  B
              Begin Commit
                Write B
                Write C
                Finish
  Read  B
Begin Commit
  Write B
  Write A
  Finish
{% endhighlight %}

Either BOCC, FOCC, or version-based OCC will reject transaction 1's read set, because
transaction 2 commits before transaction 1, and writes into the read set of the latter.
On the other hand, the schedule is serializable, as all conflicts are from transaction 2 to
transaction 1, and the overall serialiation order can be determined. 

**Serializable Non-OCC Schedule Example 2:**
{: id="serializable-non-occ-example-2"}
{% highlight C %}
   Txn 1         Txn 2
   Begin 
  Read  A
  Read  B
                 Begin
                Read  A
                Read  B
              Begin Commit
                Write A
                Write B
                Finish
  
Begin Commit
  Write C
  Write D
  Finish
{% endhighlight %}

The above schedule is also serializable, as all conflicts are from transaction 1 to transaction 2.
Compared with the previous one, this example is more illustrative of the limitation of OCC's scheduling power.
OCC serializes transactions based on the order they begin validation. Such artificial enforcement of ordering
based on a single event may not best describe the way that transactions actually interact. As a consequence, 
serializable schedules like this one will be rejected if the actual directions of conflicts differ from the order 
that transactions begin validation. 

Some data-driven OCC schemes do not serialize transactions on a globally agreed event. The commit timestamp is
instead computed based on the read and write sets. Essentially, transactions are allowed to adjust its commit timestamp
dynamically by inferring the best location to place itself. We do not cover details here. Interested 
readers are referred to [][][][] for more information.

### Reading the Partial Commit

In the previous discussion, we have seen solutions using post-read validation to detect read-write races when the committing 
transaction begins commit after the reading transaction obtained bt. The same technique also applies to
solving the read-write race when the committing transaction begins before reading transactions obtain bt. Care must be taken,
however, on the maintenance of the global timestamp counter. Otherwise, partially committed write sets can be read
by the reading transaction. Even worse, post-read validation cannot detect such inconsistent reads. In the 
example below, we assume version-base validation. The timestamp counter is incremented before versions and values are updated.

**Reading Partial Commit Example:**
{% highlight C %}
/*
 * Assume the global timestamp counter is 100 before transactions start, and 
 * all data items have initial timestamp 100
 */
      Txn 1                   Txn 2
   Begin @ 100
      Read A
      Read B
 Begin Commit @ 101
Check A (bt >= A.ws)  
Check B (bt >= B.ws)
  Write A @ 101
                           Begin @ 101
                             Read  A
                             Read  B
  Write B @ 101
     Finish
                        Begin Commit @ 102
                       Check A (bt >= A.ws)  
                       Check B (bt >= B.ws)
                             Finish
{% endhighlight %}

The schedule in this example is non-serializable. Although transaction 2 validates its read
set using bt, reading from an partially committed write set still remains undetected. The reason is that
in version-based OCC scheme, transaction commits are serialized by the order they obtain ct.
Similarly, transaction commit and transaction begin are serialized by the order they obtain ct and bt.
In this example, when transaction 1 increments the timestamp counter to 101, it is logically committed. Read phases that 
begin after the commit point is serialized after the commit, and should therefore read updated values. Failing to write back
dirty values before it is read by a reading transaction that starts after the commit point will violate the serialization 
order. Even worse, as shown in the example, if ct is obtained "too early", meaning that the transaction logically
commits before it finishes writing back dirty values, the violation cannot even be detected by post-read validation.

Incrementing the global timestamp counter *after* updating data items solves the problem. If the read phase begins before
incrementing the global timestamp counter, suggesting that the read phase may overlap with the write phase, then (1) 
the reading transaction must enter validation phase after the current committing transaction leaves write phase, because 
validation and write phases are serialized. (2) When the reading transaction enters validation phase, the wt of data items 
that the committing transaction writes into must be greater than the reading transaction's bt, because bt is obtained before 
ct (and hence wt of data items) is obtained. On the other hand, if the read phase begins after incrementing the 
global timestamp counter, then it is guaranteed that the transaction reads consistent values, because the write phase
has already completed. 

Another simple solution is to just disallow new transactions from obtaining bt when a committing transaction is 
performing write back. Write phases are therefore guaranteed not to interleave with transactional reads. In serial
validation-write OCC, this is equivalent to using the same critical section that serializes validation and write phases 
to obtain bt. Parallelism seems to be restricted in this case, because new transactions may never obtain its bt if 
the critical section is always occupied by committing transactions. We argue, however, starvation is not an issue,
as this process is self-stabilizing via negative feedback: The more starved new transactions become, the less contention 
it will be on the critical section, because less and less transactions will be able to start and hence commit.

Value-based validation can also catch race conditions of this kind. After entering the critical section, for each
element in the read set, the validating transaction re-reads the item, and compare its value with the original value
the first time the read operation is performed. Value-based validation does not maintain per-item metadata, which saves 
global storage. The trade-off is that the read set must include data item values in addition to their addresses.
Conflicts induced by false sharing can be reduced in this scheme if the granularity of reads and writes differ
from the granularity of metadata bookkeeping.

There are schedules in which reading transactions read consistently, but are wrongly identified as violating the serialization 
order. If the reading transaction reads updated values of the committing transaction, but obtains bt before the committing 
transaction finishes the write phase and then obtains ct, the reading transaction will be aborted later during validation. 

### Broken Read-Modify-Write

OCC features a Read-Modify-Write (RMW) execution pattern. Atomic read phases (with regard to concurrent writes) and atomic 
write phases (with regard to concurrent writes) are necessary for a schedule to be accepted by OCC, which generates serializable 
schedules. The atomicity of read and write phases alone, however, are not sufficient to ensure serializability. 
Even if read and write phases are atomic with regard to concurrent writes, if some interleaving transaction updates data 
items after read phase completes and before the serial validation-write phase starts, the schedule can become
non-serializable, as shown in the example below:

**Broken Read-Modify-Write Example:**
{% highlight C %}
   Txn 1         Txn 2
   Begin 
  Read  A
  Read  C
                 Begin
                Read  E
                Read  F
              Begin Commit
                Write A
                Write B
                Finish
Begin Commit
  Write B
  Write D
  Finish
{% endhighlight %}

A dependency cycle exists between the two transactions. Transaction 2 writes A after transaction 1 reads it. 
Meanwhile, transaction 1 writes B after transaction 2 writes it. In the example, both the read phase
and the write phase are atomic, as they are not interleaved with any conflicting operations from another transaction. 
The serializability, however, can still not be guaranteed if another transaction commits in-between.

Fortunately, the broken Read-Modify-Write scenario is just a special case of Racing Read and Write Phases. Post-read
validation detects this anomaly by enforcing transaction 1 in the above example to serialize
after transaction 2 which obtains ct earlier. The point we are trying to make here is that, even if incremental 
read validation can detect some violations early, they could not replace the final post-read validation
performed within the critical section. It is possible that each incremental validation succeeded, but the final
execution is non-serializable. 

If we think of the read-validate pair as "virtual" lock-unlock (if multiple validations are performed on
a data item, only the last validation is unlock) and the critical section as "virtually" locking the write set (since
transactions perform and only perform writes to data items in the critical section), then OCC 
is quite similar to 2PL. Transactions first lock the read set during the read phase, and then
lock the write set on entering of the critical section. This process corresponds to 2PL grow phase, where
locks can only be acquired and none can be released. Post-read validation aborts the thread
if the locking discipline is violated, i.e. a conflicting operation has occurred on a data item protected
by "virtual read lock". Locking discipline for "virtual write locks", on ther other hand,
is always observed, as virtual write locks are implemented using a critical section. After post-read validation,
the transaction enters 2PL shrink phase, where it releases all virtual read locks (no longer cares whether data
items are modified), writes back all dirty values, and then releases all write locks by exiting the critical section.
The importance of post-read validation is hence obvious: If post-read validation is not performed inside the critical
section after all virtual locks are acquired, then the 2PL proprety of OCC schedules no longer holds, because virtual read 
locks are released before virtual write locks are acquired. As shown in the example above, another thread
may commit in-between without being detected, making the entire schedule non-serializable.

There is one special case, however, that incremental validation suffices to guarantee serializability. For read-only
transactions, if incremental validation is performed on every read, or at least on the last read, then a separate 
post-read validation phase is unnecessary, as no virtual write lock is acquired. 

Non-atomic Read-Modify-Write does not always result in non-serializable schedules. As shown in 
[Serializable Non-OCC Schedule Example 2](#serializable-non-occ-example-2) of the previous section, transaction 2
begins and commits between transaction 1's read phase and serial validation-write phase. Transaction 2's write
set also has a non-empty intersection with transaction 1's read set, which implies transaction 1 would fail validation.
Nevertheless, the schedule is serializable, and transaction 1 is serialized before transaction 2.

### Racing Writes

Serial validation and write phases are assumed in above sections. In order to validate, transactions first
tries to enter a critical section, which is equivalent to locking the write set. Transactions exit the critical
section only after they have completed writing back dirty values. In this section, the restriction that validation
and write phases must be serialized is relaxed. As we shall see later, more race conditions will arise if transactions
are allowed to commit concurrently. Solutions for detecting these races are also covered. By supporting concurrent 
commits, OCC can expose extra degrees of parallelism and is hence expected to perform better in highly contended workloads.

One important observation is that, in the serial validation and write scheme, transactions possessing disjoint write 
sets are unnecessarily serialized. Let's ignore read sets for a while and only consider write-write conflicts, 
because read-write conflicts can be detected by post-read validation. For transactions that write different data items,
there is no logical partial ordering between them as they can never conflict with each other via data items 
that are written by multiple transactions. Serial validation and write phases, however, impose a global total ordering
among all transactions. The global total ordering is always obeyed in terms of write-write conflicts, because write 
phase is within the same critical section that transactions are serialized. Read-write conflicts also obey the global
total ordering, because they are detected against either "older" or "younger" transactions within the critical section. 
As long as transactions maintain the invariant that the direction of conflicts are consistent 
with this somewhat "artificial" global total ordering, then the entire execution history must be serializable because 
conflict cycles cannot form. 

For a validating transaction, all other transactions are either in their read phase (including waiting for the critical 
section), which cannot affect the consistency of its reads, or have already completed write phase and exited the critical section, 
as only one transaction, i.e. the validating transaction, can be in the critical section. In this case, determining the set of 
transactions to validate against is trivial, because only currently completed transactions could possibly affect the consistency of 
reads. As we have seen in the BOCC scheme with serial validation, the validating transaction samples the "last committed" global 
timestamp counter before read phase begins and after entering the critical section. Validation is then performed against
transactions committed within this time range.

If multiple transactions are allowed to commit in parallel, then for any transaction T that just finishes its read phase,
other transactions can be divided similarly into three classes: (1) Have not finished reading. They will not be considered
for backward validation as they do not affect the read phase of T. (2) Finished read phase, but have not completed. Transactions
of this class can be either validating or writing back dirty values. T needs to validate its read set against their write sets, 
as there is no way to know whether their write phases overlapped with T's read phase. Furthermore, write-write conflicts 
should also be checked by intersecting T's write set with these transactions' write sets, because there is also no way 
to know whether T's write phase, after validation, can overlap with their write phases. (3) Completed. Transactions of this class is 
validated against for read-write conflicts as in serial validation.

For transaction T to obtain a list of committing and committed transactions, in addition to the global timestamp counter as
in serial validation BOCC, a "committing transactions" set is also needed. The set keeps track of all transactions that finished read 
phase, and is currently validating itself or writing back dirty values. When T finishes its read phase, it enters
a short critical section in which the following is performed: (1) Take a copy of the committing transactions set; (2) Read the current 
global timestamp counter; (3) Add itself into the set. The value of the global counter indicates the timestamp of the last committed 
transaction. The copy of the set contains transactions that are potentially in the write phase
at the moment the critical section is entered. As transactions in the set complete and remove themselves from the set via another 
critical section, the set may become stale. The correctness of validation is not affected, though, because read-write conflicts
are checked for transactions in both committing state and completed state. Even if transactions in committing state can 
transit to completed state after T copied the set, their write sets are always checked against T's read set.
No read-write conflict can be missed in this case.
 
In order to validate, the following check is performed: (1) For transactions in the copy of the committing transactions set, intersect
T's read set and write set with their write sets. On any non-empty intersection T aborts. 
(2) For transactions whose commit timestamp is between bt and ct, where bt is the value of the counter when T begins and ct
is the value of the counter obtained in the critical section, intersect T's read set with their write sets.
On any non-empty intersection T aborts. The second check is identical to the backward validation process of BOCC. 

After validation, transaction T enters write phase and writes back dirty values. On completion of the write phase,
T enters the second critical section, which is synchronized with the one it entered before validation. Two
actions are performed in the critical section: (1) T removes itself from the committing transactions set; 
(2) T increments the global timestamp counter, and tags its write set with the timestamp value after the increment.
The tagged write set is then archived. T is considered as completed after it exits the critical section.

BOCC with parallel validation no longer guarantees that the serialization order of transactions is the order 
that they complete. Actually, the following may happen:

{% highlight C %}
   Txn 1         Txn 2
   Begin 
  Read  A
  Read  C
                 Begin
                Read  E
                Read  F
              Begin Commit
                Write A
                Write B
                Finish
Begin Commit
  Write B
  Write D
  Finish
{% endhighlight %}