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

### Racing Read and Write Phase

Conflicting read and write phases is the most common form of races in OCC. If the write phase
starts after the reading transaction began, and writes into data items that are also in the
reading transaction's read set, then non-serializable schedules can occur in the form of
RAW and WAR dependency cycles, as shown below.

**Racing Read and Write Phase Example:**
{% highlight C %}
   Txn 1         Txn 2
   Begin 
  Load  A
              Begin Commit
                Store A
                Store B
                Finish
  Load  B
   ....
{% endhighlight %}

Note that in this article, we deliberately make a distinction between the two 
possibilities where the committing transaction enters write phase *after* the other transaction begins read
phase, and the opposite. This is because they require quite different solutions to deal with. In this section,
only the former case is addressed. 

In the given example, transaction 2 begins its write phase after transaction 1 begins 
read phase. They collide on data items A and B. If we take into consideration the logical 
serialization order of OCC, which is usually the order that transaction finishes validation, it is obvious that 
transaction 1 just performs the read operation "too early". When transaction 2 decides to commit,
it is serialized before transaction 1. Transaction 1's first read operation, therefore, must actually
return the updated value of A. Failing to observe this order will result in conflicts, as in our example.

A few techniques can be applied to prevent the race condition. The essence of the problem is to detect write 
operations by committing transactions on data items that the reading transaction has accessed. As the 
reading transaction must be serialized after concurrent writing transactions who have already made commit deicisions,
any overwrite of values in its read set would indicate a commit order violation. Detecting these violating writes 
requires some post validation of the read set. In the following discussion, we assume serialized validation and write 
phases. Concurrent commits is possible, but is discussed in a separate section.

In the classical Backward OCC (BOCC) design, the validation is conducted by having reader transactions remember 
committed transactions during its read phase. On validation, the read set of the transaction and write sets from 
committed write phases are tested for non-empty intersections. Tracking committing transactions during the read 
phase can be achieved by using a timestamp counter. The counter is incremented when a transaction completes the 
write phase, and tagges its write set with the value of the counter after the increment. Meanwhile, transactions 
in the read phase read the counter before the first read operation and after it enters validation. Write sets whose 
tags are between this two timestamps are obliged to be checked. 

An alternative approach is to have committing transactions 
broadcast their commit decisions together with a reference to its write set to all reader transactions,
validating in the forward direction (Forward OCC, FOCC). 
A reader transaction receiving the broadcast first checks its current read set against the broadcasted write set,
and can optionally abort early on a non-empty intersection. Reader transactions also needs to buffer the 
broadcast. They either test every single read operation with all write sets, or perform a bulk validation
after the read phase. Any hit or non-empty intersection indicates a possibly "early read", and will cause an abort. 

We use BOCC and FOCC as a starting point to demonstrate what OCC algorithms should validate in general. BOCC and FOCC
with serial validation do not allow races that are detrimental to correctness. 
In the following discussion, however, as we introduce fine grained version-based validation and parallel commits, 
we shall see that some races are common design fallacies if the design is not verified carefully. 

Fine grained per-element version-based validation can effectively reduce validation overhead 
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
other transaction has ever committed, no data item can be possibly updated since transaction begin.

There are schedules, however, that OCC does not accept, but are actually serializable. We give one in the example below: 

**Serializable Non-OCC Schedule Example 1:**
{% highlight C %}
   Txn 1         Txn 2
   Begin 
  Load  A
                 Begin
                Load  A
                Load  B
              Begin Commit
                Store B
                Store C
                Finish
  Load  B
Begin Commit
  Store B
  Store A
  Finish
{% endhighlight %}

Either BOCC, FOCC, or version-based OCC will reject transaction 1's read set, because
transaction 2 commits before transaction 1, and writes into the read set of the latter.
On the other hand, the schedule is serializable, as all conflicts are from transaction 2 to
transaction 1, and the overall serialiation order can be determined. 

**Serializable Non-OCC Schedule Example 2:**
{% highlight C %}
   Txn 1         Txn 2
   Begin 
  Load  A
  Load  B
                 Begin
                Load  A
                Load  B
              Begin Commit
                Store A
                Store B
                Finish
  
Begin Commit
  Store C
  Store D
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

In the above 

### Racing Writes

### Broken Read-Modify-Write