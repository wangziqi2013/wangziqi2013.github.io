---
layout: post
title:  "Reader Validation, Two Phase Locking, and Optimistic Concurrency Control"
date:   2018-03-09 03:32:00 -0500
---

Reader validation is where many different HTM and STM designs diverge. In order to understand why and how the 
validation based concurrency control is designed, and how to reason about it, we take an approach that compares
read-validation based protocol with what we are already familiar with: the 2PL protocol.

In general, read validation is performed if a reader has acquired a cache line in shared mode without locking it using 2PL
principle, i.e. the reader allows other txns to access the cache line by acquiring exclusive ownership before the reader commits. 
In 2PL, the read lock prevents another txn from setting a write lock and writing into the cache line, and hence 
serializing itself after the reader txn. This could potentially lead to a cyclic dependency if the reader later establishes a reverse 
dependency with the writer txn by reading the same cache line again, or reading another cache line updated by the writer, 
or writing into any updated cache line. If the reader optimistically assumes no writer modifies the cache line, and hence
does not require the cache line to stay in L1 private cache till txn commit point which is equivalent to read lock, then it either 
needs to check the validity of the cache line after the last usage of it, or 
somehow let the first writer of the cache line notify readers that the assumption no long holds before writers publishing their write 
sets. For lazy versioning, this happens on validation stage, and for eager versioning, this happens on the first transactoinal write. If 
we implement the former, reader txns may not realize the fact that it has read inconsistent state until validation, resulting in 
what we call as "zombine" txns, as the reader now bases its action on a set of data that should never
occur as possible inputs in a serial environment. The result of zombie execution is, in general, undefined.

If you are familiar with Optimistic Concurrency Control (OCC), the two ways of validating read sets are exactly
two flavors of OCC: If reader txns validate their read sets before the write phase, then it is Forward OCC (FOCC), because reader 
checks its read set against those txns that have already committed (and hence "forward" in time). If writer txns 
notify readers before writers' write phase if its write set overlaps with readers' read sets, then it is Backward OCC (BOCC).

(The next paragraph talks concrete impl. of validation for BOCC and FOCC, using versions, global counter, broadcast)

(Talk about the degree of parallelism of read validation)

(To be finished)