---
layout: post
title:  "Understanding Discrete Event Contention Simulation in zSim"
date:   2020-01-22 16:57:00 -0500
categories: article
ontop: true
---

## Introduction

In previous articles of this series, we have covered cache system simulation and its static timing model with the assumption
that only one thread accesses the cache hierarchy at a time. In practice, however, contention may occur at instruction 
and thread level, causing extra delay due to resource hazards. For example, when multiple instructions (uops) from the
pipeline cause cache misses, each of the instruction (uop) must be allocated a MSHR (miss status handling register) for 
remembering the missing status. When the cache miss is fulfilled, the MSHR provides information for properly updating
data and state of the cache line. Similarly, when multiple requests attempt to access the cache tag, only one request can
be granted permission, since most cache controllers have only one circuit for reading and updating the tag array. 

These contention situations are not properly simulated in the static cache timing model, since interactions between threads
are not taken into consideration. Instead, we rely on the locking protocol to maintain an illustration that at any time
during the cache transaction, only the current request may access the entire hierarchy. This technique simplifies cache
system implementation, at the cost of ignoring potentially complicated interactions between different threads. In this article,
we discuss zSim's contention model and direcrete event contention simulation mechanism in details. We first introduce the 
bound-weave model of zSim in order for readers to grasp the basic idea of using dependency chains and static latencies
to simulate run-time contention overhead. We then cover the implementation details of contention simulation components 
in zSim. We begin with timing event and event queue infrastructure, which is followed by contention model of timing caches. 
We next discuss how contention simulation interacts with simulated cores and how they affects core clocks. We conclude this
article by discussing how contention simulation can be optimized using parallel domains.

## Bound-Weave Simulation

zSim divides timing simulation into two logically separate phases, bound phase and weave phase. In the bound phase, all
threads are scheduled to only simulate a relatively short interval (e.g. 10000 cycles), before they are swapped out by
the scheduler. Note that if the number of cores is smaller than the number of simulated threads, some cores might be
scheduled to simulate more than one thread. The simulation guarantees that the thread has exclusive ownership of the 
core while it is simulated in the bound phase. Different threads are scheduled on the same core serially without any
interleaving. During the bound phase, threads record critical events during memory operations, such as cache tag access, 
cache eviction, and cache write back, and link these events together in the order that they occur as an event chain. Note
that the event chain is not necessarily a singly linked list. In fact, in some cases, one event node may have multiple 
children nodes to model concurrent hardware operations. All events are assumed to be contention-free, and only the 
static latency of the component is considered when computing operation timing, as we have described in the previous cache
simulation article. For example, 

### Zero Load Letency Clock