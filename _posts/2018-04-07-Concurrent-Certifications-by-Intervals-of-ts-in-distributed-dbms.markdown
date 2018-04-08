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

Not all serializable schedules are fixed by the above technique. In the following example, although transaction 1
serializes before transaction 2, no matter how fine grained the conflict detection mechanism is, transaction 1 would
fail validation.

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