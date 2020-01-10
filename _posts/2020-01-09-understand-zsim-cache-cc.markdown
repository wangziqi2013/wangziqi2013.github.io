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

### Source Files and Documentation

We list source files and modules related to our discussion in the following table.

| File Name                        | Important Modules/Declarations |
|:--------------------------------:|--------------------------------|
| cache.h/cpp | `class Cache`'s `access()` and `invalidate()` shows how synchronization routines are called during a cache operation. |
| coherence\_ctrl.h/cpp | `class MESITopCC` and `class MESIBottomCC` implement request lock and invalidation lock respectively. |
| filter\_cache.h/cpp | `class FilterCache` implements a low overhead traffic filter above L1 cache to avoid the locking protocol. |
| init.cpp | Initialization of filter caches |
{:.mbtablestyle}

Besides, our discussion is based on a tutorial on zSim memory simulation published by zSim developers at MIT. The tutorial
is focused on teaching the audience on how to extend zSim with user customized modules, while this article is more focused 
on explaining how things work in zSim's existing code base. The tutorial can be found 
[here](http://zsim.csail.mit.edu/tutorial/slides/memory.pdf).

## Concurrency Control in Cache Objects

### Two-Phase Locking (2PL)

Generally speaking, two-phase locking is the most commonly used lock-based concurrency control protocol. It is based on
the lock and unlock primitive, which acquires and releases exclusive access of a thread to a single object. zSim's cache 
concurrency control protocol is also a variant of 2PL. We briefly describe 2PL in this section. 

2PL requires objects to be locked before they are accessed. The read and write set may not be known in advance, which can 
be derived dynamically as the critical section is executed. The most important aspect of 2PL is the two-phased property:
Objects are locked as they are accessed within a critical section. No object should be released before the last object
is locked. This property essentially divides the execution of the critial section into two phases: a growing phase in which
locks can only be acquired, and a shrinking phase in which locks can only be released. 2PL property guarantees serializability.
One easy way to visualize this is to consider what if one thread A blocks another thread B by holding a lock B intends to
acquire. In this case, B must serialize after A, and not vice versa, since B can only read or overwrite state written by A,
but A must not access state written by B. We prove this by contradiction. The first half is easy, since B blocks on an
object A will read or write. After A releases the lock, B could read or write the object as well, serializing itself
after A. The second half can be proven by contradiction. Assume that A also accesses B's state. This implies that thread
A must have acquired a lock B releases. According to the 2PL property, B must not release any lock before it acquires 
all locks for objects in its working set. We can infer that B must have already been in the shrinking phase. This, however,
is inconsistent with the fact that B blocks on A, since this implies that B is still in growing phase, and has at least
one or more locks to acquire. A contradiction!