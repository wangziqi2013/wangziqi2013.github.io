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
interleaving. 

### The Bound Phase

During the bound phase, threads record critical events during memory operations, such as cache tag access, 
cache eviction, and cache write back, and link these events together in the order that they occur as an event chain. Note
that the event chain is not necessarily a singly linked list. In fact, in some cases, one event node may have multiple 
children nodes to model concurrent hardware operations. All events are assumed to be contention-free, and only the 
static latency of the component is considered when computing operation timing, as we have described in the previous cache
simulation article. For example, during bound phase simulation, MSHRs are assumed to be non-existent, and cache tag accesses
always take `accLat` cycles. Core cycles are also updated using timing derived from static latencies. 

One of the most fundamental assumptions in zSim is that the access path derived during the bound phase is a very good 
approximation of the actual access path in an actual execution where contention is present. In other words, the part of
the memory hierarchy that will be traversed will not change much between isolated simulation and concurrent execution.
Only the timing of the access will change due to contention and resource hazards. The zSim paper also proves that 
"path-altering interferences" are very rare compared with the number of accesses.

The bound phase only runs for a short interval to avoid significant clock skew between simulated cores. Since zSim does 
not impose much control over the execution of threads, the actual simulation timing may be inconsistent with clocks of 
simulated cores, resuling in clock inversion. For example, during the simulation of two cores, C1 and C2, since the 
simulated thread running on C1 and C2 run independently without simulator synchronization within the bound phase interval,
it is possible that after C1 performs an operation at simulated clock t1 in real time clock T1, C2 performs another operation
at simulated clock t2 in real time clock T2, where t1 < t2 but T2 < T1. In this case, the simulated behavior of C2 may 
disagree with actual behavior on real hardware, since C2 observes the simulated state after C1 modifies it in real time, 
but the actual state it observes should not contain any modification happening after T2. zSim admits clock inversion like
this during a bound phase, but since threads synchronize with each other constantly, the aggregated amount of skews
are expected to be small. 

### The Weave Phase

After all threads finish their bound phase, the weave phase is started to simulate contention and adjust clock cycles of 
simulated cores using discrete event simulation (DES). Recall that simulated cores build event chains during the bound 
phase using the static, contention-free timing model. Static latencies represent the minimum number of cycles between two 
events, which can be "stretched" to account for contention and resource hazards. During the weave phase, all events from 
the cores are enqueued into the corresponding cycles, and then executed. At the beginning of the weave phase, only the 
earliest event is enqueued and executed. By executing an event at cycle `C`, we may add extra delay `t`, in addition to the
static delay `D`, to the execution of its children events, if there is another event (from the same core or from other cores) 
interfering with the current event in cycle `C`. In this case, the execution of its children events will happen at 
cycle `C + D + t` rather than cycle `C + D` as in bound phase simulation. 

The weave phase may not simulate all events generated by the most recent bound phase. In fact, given an interval size of 
`I`, the weave phase will stop after the next event's start cycle exceeds cycle `I`. This is to guarantee that the clocks
of all cores will be driven forward in locksteps without introducing too much skews by long latency events. Otherwise,
imagine the case where some core enqueued an event whose latency is even longer than the interval size, the core's clock will
be driven forward by a large amount if all events generated during the bound phase are simulated.

If a long event introduces a large clock skew, such that the core's clock even exceeds the next interval boundary, the 
next bound phase will be skipped, and the core directly run the weave phase after all bound phases are completed. Otherwise
the core continues bound phase execution of the next basic block (we only switch phase on basic block boundaries; see below).

### Zero Load Letency Clock