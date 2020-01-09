---
layout: post
title:  "Understanding Cache Coherence Concurrency Control Protocol in zSim"
date:   2020-01-09 17:12:00 -0500
categories: article
ontop: true
---

## Introduction

In a previuos article, we discussed cache coherence protocol implementation and simulation in zSim. We assumed a no-race
condition context in which the current thread has full permission to access the entire cache hierarchy, and no intervening
operations from other theads will alter the cache state. While this assumption simplifies discussion, it is unrealistic 
in practice, since zSim is designed to simulate multiple threads concurrently. To deal with concurrency, we must synchronize
threads properly to achieve the following two goals. First, the state of a `MemObject`, such as the tag array and coherence
state array, must be consistent while a thread accesses them. Partial states must not be observed. Second, operations on
the cache object must serialize property, forming a global partial ordering. If one thread observes or overwrites the 
state written by another thread, serializing after it, then the latter must not serialize before the former by observing 
or overwriting states written by the former. This way, cache operations can form a global partial ordering, which allows 
a total ordering to be determined. Logically speaking, in a total ordering, the concurrent execution of cache operations 
is equivalent to a serialized execution in terms of input, output of each operation as well as the final state. The
order of serialized execution is given by the total ordering.

In the following discussion, we introduce thread synchronization within zSim's cache hierarchy implementation. Note that
concurrency control here does not refer to concurrency enabled coherence protocol with transient states. zSim only models 
the basic MESI protocol in which all states are stable. Transient state simulation requires a complicated state machine, 
which cannot be easily implemented and verified. zSim applies concurrency control protocol only to protect its internal
data structure and to ensure correct semantics of coherence actions. 

## Source Files and Documentation

We list source files and modules related to our discussion in the following table.

| File Name                        | Important Modules/Declarations |
|:--------------------------------:|--------------------------------|
| cache.h/cpp | `class Cache`'s `access()` and `invalidate()` shows how synchronization routines are called during a cache operation. |
| coherence\_ctrl.h/cpp | `class MESITopCC` and `class MESIBottomCC` implement request lock and invalidation lock respectively. |
| filter\_cache.h/cpp | `class FilterCache` implements a low overhead traffic filter above L1 cache to avoid the locking protocol. |
| init.cpp | Initialization of filter caches |
{:.mbtablestyle}