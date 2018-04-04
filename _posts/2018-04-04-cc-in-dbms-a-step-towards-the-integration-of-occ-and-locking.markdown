---
layout: paper-summary
title:  "Concurrency Control in Database Systems: A Step Towards the Integration of Optimistic Methods and Locking"
date:   2018-04-04 16:17:00 -0500
categories: paper
paper_title: "Concurrency Control in Database Systems: A Step Towards the Integration of Optimistic Methods and Locking"
paper_link: https://dl.acm.org/citation.cfm?id=809759
paper_keyword: OCC; 2PL
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

Since transaction 2 begins commit after transaction 1 begins, transaction 1 will intersect its read set
which contains A and B with transaction 2's write set, which contains A and B also. The non-empty
intersection indicates that transaction 1 should abort. The schedule, however, is serializable, with
transaction 1 serialized after transaction 2.