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