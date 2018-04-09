---
layout: paper-summary
title:  "Using dynamic adjustment of serialization order for real-time database systems"
date:   2018-04-09 16:15:00 -0500
categories: paper
paper_title: "Using dynamic adjustment of serialization order for real-time database systems"
paper_link: https://ieeexplore.ieee.org/document/393514/
paper_keyword: FOCC; TIOCC
paper_year: 1993
rw_set: Lock Table
htm_cd: Eager (FOCC)
htm_cr: Eager (FOCC)
version_mgmt: Lazy
---

This paper proposes a time interval based OCC algorithm. The algorithm has been discussed in [another
paper review]({% post_url 2018-04-07-Concurrent-Certifications-by-Intervals-of-ts-in-distributed-dbms %}) 
in detail, so we only discuss what is not covered previously. Before that, we first go through a brief 
overview of the algorithm outline.

The time interval based OCC (TIOCC) differs from classical BOCC such that the serialization order of 
transactions is not determined by the order they start validation. Instead, each transaction is assigned 
a time interval in which the transaction is logically consistent. The commit timestamp of transactions are
selected from this time interval when they are about to commit. Each data item is associated with most recent 
read and write timestamps (rts and wts respectively). These timestamps are updated whenever a logically newer 
transaction that reads or writes them commits. When a reading transaction accesses these data items, it adjusts 
the time interval based on the type of operation and either the rts or wts of the data item. For example, when
reading a data item, the lower bound of the interval is set to the old lower bound or the wts, whichever is 
larger. Similarly, when pre-writing a data item in the read phase, the lower bound of the interval is set to the 
old lower bound or the rts or the wts, whichever is larger. The goal of tightening the interval's lower bound is to serialize
the current reading transaction after committed transactions. On transaction commit, the committing transaction
first enters a critical section which blocks commit requests and data item access requests. Then the committing 
transaction's write set is broadcasted to all reading transactions together with the selected commit timestamp. 
On receiving the broadcast, reading transactions compare the write set with its own read and write set. If the 
write set has a non-empty intersection with its read set, then the upper bound of the interval is set to the 
old upper bound or the broadcasted commit timestamp, whichever is smaller. If the write set has a non-empty intersection
with its write set, then the lower bound of the interval is set to the old lower bound or the broadcasted commit 
timestamp, whichever is larger. The FOCC-style interval adjustment serializes reading transactions with the 
transaction just committed, as if the commit operation logically happens after all uncommitted reads, and 
before all uncommitted writes. If in any of the above cases, the interval closes after the adjustment, i.e. the upper 
bound crosses the lower bound, then the current transaction must abort as it can no longer serialize with committed 
transactions. Otherwise, if a committing transaction passes validation, it enters write phase, in which all dirty 
values are written back and timestamps of data items are updated accordingly.

In this paper, a concrete implementation is given by using locks. Two global data structures are proposed. One is 
a global transaction table, which stores active transactions and their read and write sets. The second is a lock
table, which stores read and write locks taken on data items. Two lock modes are needed: Read lock are taken on
reading or pre-writing a data item; Write locks are taken for items in the write set before the transaction attepmts 
to commit. Read and write locks are incompatible with each other. For both modes, a list of current lock holders
must be available to perform FOCC.

Although using locks to implement OCC seems nonsense, as the major advantage of OCC over 2PL is increased parallelism
by allowing transactions to execute read phases in parallel, the proposed implementation eliminates some disadvantages
of naive 2PL. For example, the duration that write locks are held is greatly reduced, because write locks are only 
acquired during validation and write phases, which are expected to be short. In contrast, a write lock must be taken
in 2PL scheme when a transaction pre-writes a data item during the read phase, as pre-writes are not buffered, and the 
uncommitted value must be prohibited from being read by other transactions to ensure recoverability.

One drawback of lock-based OCC is the possibility of deadlocks. In the proposed scheme, two or more transactions can 
deadlock not only when they lock the write set in a conflicting order (which is common to all OCC schcmes
that lock the write set), but also when they try to acquire write lock for a data item and the item is in
another transaction's read set. The example below shall clarify:

**Read-Write Deadlock Example:**
{% highlight C %}
   Txn 1         Txn 2
   Begin 
  Read  A
  PreW  B
                 Begin
                Read  B
                PreW  A
              Begin Commit
                WLock A
                  ...
Begin Commit
  WLock B
    ...
{% endhighlight %}

In the above example, transaction 1 and 2 writes disjoint data items. A deadlock occurs when they
acquire locks for A and B, as both transactions' write sets overlap with another transaction's read
set. It is therefore expected that more deadlock may arise in the lock-based implementation. Although in
the paper it is claimed that the lock-based approach is deadlock-free, the way it is described does not
justify such claim. The detailed description of the lock-based FOCC scheme is actually in another
paper.