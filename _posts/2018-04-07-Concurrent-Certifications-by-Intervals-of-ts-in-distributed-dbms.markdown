---
layout: paper-summary
title:  "Concurrent Certifications by Intervals of Timestamps in Distributed Database Systems"
date:   2018-04-07 21:39:00 -0500
categories: paper
paper_title: "Concurrent Certifications by Intervals of Timestamps in Distributed Database Systems"
paper_link: http://ieeexplore.ieee.org/document/1702233/
paper_keyword: OCC; FOCC; Dynamic Timestamp Allocation
paper_year: 1983
rw_set: Set
htm_cd: Lazy 
htm_cr: Lazy
version_mgmt: Lazy
---

This paper proposes a new OCC algorithm that computes the commit timestamp (ct) in a distributed way.
Classical OCC algorithms like set-intersection based and version-based OCC all require a total ordering
between transactions, which is determined by the order that they finish the write phase. In this scheme,
timestamps are allocated by atomically incrementing a centralized global timestamp counter. As the 
number of processors and distances between processors and memory modules increase, the centralized
counter will become a major bottleneck and harms scalability. Furthermore, read operations determine
their relative order with committed transactions in order to detect overlapping read and write phases.
This is usually achieved by reading the global timestamp counter as the begin timestamp (bt) without 
incrementing it at the beginning of the read phase. The validation routine compares the most up-to-date 
timestamp of data items with the bt. If bt is smaller, then the validating transaction aborts, because a
write has occurred between bt is obtained and the start of validation. 

This above scheme, although fairly simple to implement, demonstrates a few undesirable properties that
we hope to avoid in today's multicore architecture. The first property is increased inter-processor traffic 
as a consequence of centralized global timestamp counter. The second property is low degree of parallelism,
because obtaining bt at the beginning of every transaction's read phase logically forces all these reads to
be performed at the exact time point when the counter is read. Any interleaving write operation by a committing
transaction on data items in current transaction's read set is considered as a violation, while in some cases,
such read-write interleaving is benevolent, as shown in the example below:

**Serializable Non-OCC Schedule Example 1:**
{% highlight C %}
   Txn 1         Txn 2
                 Begin
                Read  A
                Read  B
              Begin Commit
                Write A
                Write B
   Begin 
  Read  A
  Read  B
              (Increment)       
                Finish
Begin Commit
  Write C
  Write D
  Finish
{% endhighlight %} 

In the above schedule, transaction 1 is serialized after transaction 2. It is illegal under timestamp-based 
and set-intersection based OCC, however, as the write timestamp (wt) of data item A and B is larger than the 
bt of transaction 1, resulting in failed validation.

Instead of obtaining bt and using bt to validate all read operations, finer grained conflict detection can be applied
by reading the data item and its wt atomically, and storing the wt in the read set as well. During version-based 
validation, the wt is re-read and compared with the wt in the read set. If they differ, then a write operation has 
been performed on the data item, and the transaction aborts. For set intersection-based validation, if the validating
transaction's read set has an non-empty intersection with a committed transaction's write set, then the wt of 
data items in both sets are compared with the ct of the committed transaction. If ct is smaller than wts of 
all data items, the validating transaction does not need to abort, because all committing writes are
performed before the corresponding reads in real-time. 

Not all serializable schedules can be accpeted by adopting the above technique. In the following example, 
although transaction 1 serializes before transaction 2, no matter how fine grained the conflict detection 
mechanism is, transaction 1 would fail validation.

**Serializable Non-OCC Schedule Example 2:**
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

In fact, classical BOCC always cannot commit transaction 1, because transactions are logically 
serialized by the order they finish write phase (which equals the order they enter validation, if
validations are performed in a critical section). If transaction 2 commits before transaction 1
begins validation, then classical BOCC will reject schedules in which transaction 1 is
serialized before transaction 2 via Write-After-Read (WAR) dependencies.

This paper prposes a different approach where transactions are not serialized by commit timestamps.
Instead, each transaction computes a commit timestamp based on the version of data items in
its read and write set. Accordingly, for each data item, two timestamps must be maintained to reflect
operations that committed transactions have performed on the item. One is read timestamp (rt),
which is updated when a transaction that read the data item commits. Another is write timestamp (wt),
which is updated when a transaction that pre-writes the data item commits. Both timestamps are made to 
never decrease. Each transaction is assigned an interval, initialized to [0, +&infin;). As they read
and per-write data items, the interval is updated using the rt and wt of the data item to establish dependencies
with committed transactions. When a transaction commits, it selects an appropriate timestamp from the interval
as its ct, and notify all active transactions of the commit action. Since timestamps are stored and computed
in a distributed way, this enhanced OCC algorithm overcomes the drawback of a centralized counter. 
We describe the algorithm in detail in the next few sections.

On transactional read, the wt of the data item is used to update transaction's interval. The interval is
intersected with [wt, +&infin;) where wt is the data item's write timestamp. If, after the intersection,
the interval closes (i.e. the range contains zero available timestamp), then the transaction aborts as a
ct cannot be found.

Similarly, on transaction write, the rt of the data item is used to update transaction's interval by
an interval intersection with [rt, +&infin;). If the resulting interval closes then the transaction must abort.

Transactions serialize themselves after committed transactions as they read and pre-write data items. This alone,
however, does not guarantee serializability of transactions, as reading transactions could conflict with each other.
The conflict, although not materialized until commit time, will need to be dealt with if both transactions are to be 
committed. For example, a transaction that reads a data item conflicts with another transaction that pre-writes the 
same data item. No matter which one commits first, the reading transaction must be serialized before the pre-writing
transaction. 

It is therefore necessary to resolve conflicts between reading transactions and the committing transaction, in addition to 
resolving conflicts with committed transactions during the read phase. The same timestamp interval technique is 
used. When a transaction commits, it first enters a critical section, which blocks all commit requests and read requests
to any data item in its write set. Blocking reads is necessary, because otherwise a read request between the validation
and the write phase may introduce a dependency cycle, as we shall see later. During validation, the transaction picks 
a commit timestamp from its interval. The selection of ct is not arbitrary, as it will affect the interval of other 
active transactions. In the paper it is recommended that the lower bound of the interval be chosen. The validation transaction
then broadcasts its write set together with its ct to all other transactions. 
After receiving the broadcast, active transactions perform a set intersection between the broadcasted write set 
and their own read and write sets. If the write-read set intersection is non-empty, then the active transaction 
upper bounds its interval using the ct in the broadcast. Similarly, if the write-write set intersection is non-empty, 
then the active transaction lower bounds its interval using the ct in the broadcast. If the interval of the active 
transaction closes after processing the broadcast, then the transaction aborts. 

During the write phase, the committing transaction writes back values in its write set. In addition, the rt and 
wt of data items in its read and write sets are updated respectively. Write timestamps are always updated to
the ct of the committing transaction. Read timestamps, on the other hand, is not updated if the current rt
is greater than the ct. This is possible because read transactions do not conflict with each other, and it is possible
that a transaction with larger ct read the item and committed before the current transaction commits.

As an optimization, during the validation phase, the broadcast can be limited only to transactions whose read set has 
a non-empty intersection with its read and write set. A reader list and writer list for every data item must be maintained 
in this case, and only the ct is broadcasted. On receiving the broadcast, active transactions adjust their 
interval accordingly.