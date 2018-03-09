---
layout: post
title:  "Reader Validation, Two Phase Locking, and Optimistic Concurrency Control"
date:   2018-03-09 03:32:00 -0500
---

Reader validation is where many different HTM and STM designs diverge. In order to understand why and how the 
validation based concurrency control is designed, and how to reason about it, we take an approach that compares
read-validation based protocol with what we are already familiar with: the 2PL protocol.

To ensure coherence of cached data while allowing every processor to manipulate data in its private L1 cache, hardware already implements 
a multi-reader, single-writer locking protocol for each individual cache line, dubbed "cache coherence protocol". We use MSI as 
an example. When a cache line is to be read, a processor sends a read-shared bus message to either the bus or the directory. The processor
will be granted the permission to read if one of the following is satisfied: (1) There are no sharing processors. The requestor will be
granted "S" state. (2) There are several sharing processors in "S" state. The requestor will also be granted "S" state. (3) There is 
exactly one processor that has the cache line in the exclusive "M" state. In this case, the write permission will first be revoked by the 
coherence protocol, and then the requestor is granted "S" state (and will receive the dirty cache line via a cache-to-cache transfer). A 
similar process will be followed 
if the requesting processor is to write into the cache line. Instead of granting an "S" state, the protocol revokes all other cache lines 
regardless of their state, and then grants "M" state to the requestor. Note that the protocol described here is not optimal,
as converting an "M" state to "S" after a write-back and graning "S" to the requestor could be more efficient. We avoid write-backs
in the discussion, because under the context of HTM, write-backs usually require some indirection mechanism which is out of the scope.


In general, read validation is performed if a reader has acquired a cache line in shared mode without locking it using 2PL
principle, i.e. the reader allows other txns to access the cache line by acquiring exclusive ownership before the reader commits. 
In 2PL, the read lock prevents another txn from setting a write lock and writing into the cache line, and hence 
serializing itself after the reader txn. This could potentially lead to a cyclic dependency if the reader later establishes a reverse 
dependency with the writer txn by reading the same cache line again, or reading another cache line updated by the writer, 
or writing into any updated cache line. If the reader optimistically assumes no writer modifies the cache line, and hence
does not require the cache line to stay in L1 private cache till txn commit point which is equivalent to holding a read lock and 
only releasing the lock after commit, then it either 
needs to check the validity of the cache line after the last usage of it, or 
somehow let the first writer of the cache line notify readers that the assumption no long holds before the writer publishing its first 
write on the cache line. For lazy versioning, this happens on validation stage, and for eager versioning, this happens on the first 
transactoinal write. If we implement the former, reader txns may not realize the fact that it has read inconsistent state until 
validation, resulting in what we call as "zombine" txns, as the reader now bases its action on a set of data that should never
occur as inputs in a serial environment. The result of zombie execution is, in general, undefined.

If you are familiar with Optimistic Concurrency Control (OCC), the two ways of validating read sets are exactly
two flavors of OCC: If reader txns validate their read sets before the write phase, then it is Forward OCC (FOCC), because reader 
checks its read set against those txns that have already committed (and hence "forward" in time). If writer txns 
notify readers before writers' write phase if its write set overlaps with readers' read sets, then it is Backward OCC (BOCC).

(The next paragraph talks concrete impl. of validation for BOCC and FOCC, using versions, global counter, broadcast)

(Talk about the degree of parallelism of read validation)

{% highlight C %}
 Txn 1               Txn 2
Read  A      
                    Read  B
                    Write A
                    Commit
Read  B
Write C
Commit
{% endhighlight %}

(To be finished)