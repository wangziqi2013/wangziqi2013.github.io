---
layout: post
title:  "Reader Validation and Two Phase Locking"
date:   2018-03-09 03:32:00 -0500
---

Reader validation is where many different HTM and STM designs diverge. In order to understand why and how the 
validatin based concurrency control is designed, and how to reason about it, we take an approach that compares
read-validation based protocol with what we are already familiar with: the 2PL protocol.

In general, read validation is required if a reader acquires a cache line in shared mode without locking it using 2PL
principle (i.e. allow other txns access the cache line by acquiring exclusive ownership before txn finishes, as required by
2PL). In 2PL, the read lock prevents another txn from grabbing a write lock and writing into the cache line, and hence 
serialize itself after the reader txn, which could potentially lead to a violation if the reader later establishes a reverse 
dependency with the writer txn (e.g. read the same cache line again, or read the updated value of the cache line, or write
onto that cache line). If the reader optimistically assumes no writer could overwrite the cache line, then it either 
needs to validate that this is indeed the case after the last usage of the cache line (i.e. after read phase), or 
let the first writer notify readers that the assumption no long holds before writers are going to write (i.e. for 
lazy versioning, this happens on validation stage; for eager versioning, this happens on first write). If we choose 
the former, reader txns may not realize the fact that it has read inconsistent state until validation, which could 
lead to serious problems, as the reader now becomes unpredicable, and may fail in an undefined manner. 
Readers of this kind are usually called "zombie" txns.

The above