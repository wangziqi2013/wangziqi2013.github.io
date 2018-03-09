---
layout: post
title:  "Reader Validation and Two Phase Locking"
date:   2018-03-09 03:32:00 -0500
---

Reader validation is where many different HTM and STM designs diverge. In order to understand why and how the 
validatin based concurrency control is designed, and how to reason about it, we take an approach that compares
read-validation based protocol with what we are already familiar with: the 2PL protocol.

In general, read validation is performed if a reader has acquired a cache line in shared mode without locking it using 2PL
principle (i.e. allow other txns access the cache line by acquiring exclusive ownership before txn finishes, as required by
2PL). In 2PL, the read lock prevents another txn from grabbing a write lock and writing into the cache line, and hence 
serializing itself after the reader txn. This could potentially lead to a violation if the reader later establishes a reverse 
dependency with the writer txn (e.g. read the same cache line again, or read the updated value of the cache line, or write
onto that cache line). If the reader optimistically assumes no writer could overwrite the cache line, then it either 
needs to check that this is indeed the case after the last usage of the cache line (i.e. after read phase), or 
let the first writer notify readers that the assumption no long holds before writers are publishing their write sets 
(i.e. for lazy versioning, this happens on validation stage; for eager versioning, this happens on first write). If we choose 
the former, reader txns may not realize the fact that it has read inconsistent state until validation, which could 
lead to what we call as "zombine" txns, as the reader now bases its action on a set of data that should never
be considered as possible inputs in a serial environment. The general result of such execution is undefined.

If you are familiar enough with Optimistic Concurrency Control (OCC), the two ways of validating read sets are exactly
two flavors of OCC: If reader txns validate their read sets before the write phase, then it is Forward OCC (FOCC), because reader 
checks its read set against those txns that have already committed (and hence "forward" in time). If writer txns 
notify readers before writers' write phase if its write set overlaps with readers' read sets, then it is Backward OCC (BOCC).

(The next paragraph talks concrete impl. of validation for BOCC and FOCC, using versions, global counter, broadcast)

(Talk about the degree of parallelism of read validation)

(To be finished)