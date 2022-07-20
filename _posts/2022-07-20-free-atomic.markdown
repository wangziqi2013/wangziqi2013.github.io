---
layout: paper-summary
title:  "Free Atomics: Hardware Atomic Operations without Fences"
date:   2022-07-20 03:56:00 -0500
categories: paper
paper_title: "Free Atomics: Hardware Atomic Operations without Fences"
paper_link: https://dl.acm.org/doi/10.1145/3470496.3527385
paper_keyword: Load Queue; Store Queue; Atomics; Memory Consistency
paper_year: ISCA 2022
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Free Atomics, a microarchitecture optimization aiming at reducing memory barrier cost of atomic 
operations.
The paper is motivated by the overhead incurred by the two implicit memory barriers surrounding x86 atomic operations.
The paper proposes removing these two barriers, allowing the load-store pair belonging to the atomic operation
to freely speculate and be reordered with regular memory operations, thus reducing the overhead.
However, without care, anomalies such as deadlocks, livelocks, and store-load forwarding may also occur after
removing the barriers, due to more complicated cases of memory access reordering.
These anomalies are addressed with either operation timeouts, or an extra hardware structure that tracks 
the ongoing status of atomic operations. 

The paper assumes a baseline implementation of atomic operations on x86 platforms that we describe as follows.
The baseline processor implements out-of-order execution with separate load and store queues. The memory consistency
model is Total Store Ordering (TSO), meaning that store-load sequence in program can be reordered as long as the 
store and load are to non-overlapping addresses, while load-load, store-store, and load-store are not reordered.
Atomic operations, consisting of a load, arithmetic, and store, are performed in an atomic manner, such that no 
other store operation may occur in-between the load and the store in the global memory consistency ordering 
(the paper explains, in later sections, that this is a type I atomic operation).
The atomic operation is decoded into several uops: a load, a store, and one or more ALUs uops.
In addition, two implicit barriers are added. The first barrier is inserted before the load uop, which prevents it
from being issued, until all earlier memory uops have successfully committed.
This barrier serves two purposes. 