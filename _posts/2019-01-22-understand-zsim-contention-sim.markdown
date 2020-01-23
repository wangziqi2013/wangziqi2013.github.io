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
`I`, the weave phase will stop after the next event's start cycle exceeds cycle `S + I` where `S` is the starting cycle
of the most recent bound phase. This is to guarantee that the clocks of all cores will be driven forward in locksteps at 
the granularity of `I` without introducing too much skews by long latency events. Otherwise, imagine the case where some 
core enqueued an event whose latency is even longer than the interval size, the core's clock will be driven forward by a 
large number if all events generated during the bound phase are simulated.

If a long event introduces a large clock skew, such that the core's clock even exceeds the next interval boundary, the 
next bound phase will be skipped, and the core directly run the weave phase after all bound phases are completed. Otherwise
the core continues bound phase execution of the next basic block (we only switch phase on basic block boundaries; see below).

One thing that worth mentioning is that zSim does not enqueue events until all their parents are completed, despite the 
fact that events can be known in advance. This is because the actual start cycle of an event can only be calculated after 
we finish simulating all parent events. In addition, if an event must be delayed by an unknown number of cycles due to 
contention or resource hazard, the event can be re-enqueued to a later cycle after its simulation. 

### Zero Load Latency Clock

zSim maintains two clocks to simplify developer's reasoning on the timing model. One clock is the `curCycle` member variable
of `class OOOCore` and other core types representing the issue cycle (or execution cycle, for simpler core types) of the 
most recent uop. `curCycle` will be adjusted by the amount of extra cycles introduced by contention simulation at the end
of every weave phase. The second clock is the global Zero Load Latency (zll) clock, which is never adjusted for contention,
and is used to represent the absolute position in the simulation timeline. The skew between the zll clock and the core's 
clock is stored as a member variable, `gapCycle`, in core recorder objects. `gapCycle` represents aggregated number of 
cycles added onto `curCycle` as a result of weave phase simulation. 

The zll clock serves as a unique reference clock for specifying time points in the bound and weave phases. The `curCycle`
of simulated cores cannot be used as reference, since `curCycle` might be "stretched" after contention simulation. For example,
image the developer refers to a time point `C2` in the current bound phase, but there is an event occuring at time `C1`,
where `C1 < C2`. If the simulation of the event at time `C2` incurs an extra delay of `D` cycles, then the actual time
point after adjustment will be `C2 + D` rather than `C2`, since all later events need to be delayed by `D` cycles as 
well. Cycle `C2` no longer refers to the time point it was supposed to after contention simulation. Instead, if we use
the zll clock of the current bound phase, and translate the zll clock by `gapCycle` cycles, the result still refers to the 
same point in the bound phase, since the zll clock is an aggregation of all weave phase adjustments.

## DES Infrastructure

The DES infrastructure consists of timing events and the event queue. Timing events are defined in timing\_event.h/cpp
as `class TimingEvent`. This class is a virtual class, meaning that it cannot be instanciated directly, and must be extended
by inheritance. Another important timing event class is `class DelayEvent` defined in the same file as the subclass of 
`class TimingEvent`. This event does nothing but simply delay the execution of all child events by a specified number of 
cycles. In the following discussion, we will see that the delay event is used universally to "fill the gap" between two 
events that have a non-zero time period between them. `class CrossingEvent` is also defined to allow multithreaded DES
of the weave phase. We delay the discussion of multithreaded simulation to the end of this article. Before that, the
contention simulation is assumed to be single threaded with only a single domain.

### Memory Management

Event objects are allocated from the heap using C++ `new` operator. The base class `TimingEvent` overrides this operator,
and adds an extra `class EventRecorder` object as argument. As a result, event objects must be allocated in the form
of replacement `new`s, which looks like the following: `new (eventRecorder) EventObjectName(args)` (`eventRecorder`
is an `EventRecorder` object). This is an optimization for memory allocation and garbage collection using slab allocators 
within `EventRecorder` objects. Memory is allocated and released in large chunks to amortize the overhead of calling C
library. In addition, a chunk is only released after all event objects in the chunk are no longer used, the status of which
is tracked by a high watermark. Correspondingly, `operator delete` is not allowed to be called on event objects, since the 
slab is freed as a whole rather than individually for each event objects.

### Timing Events

The timing event object has a few member variables with the word "cycle" in it. Among them, `privCycle` seems to be unused 
anywhere except in event queue function `enqueue()` and `enqueueSyned()` to remember the cycle the event is most
recently enqueued. This variable seems not being used elsewhere, which is likely just added for debugging (I did a 
`grep -r "privCycle" --exclude tags` and only found three instances; One is the member definition and the other two 
are assignments). The second variable is `cycle`, which stores the largest cycle when all parents are finished. If there
are more than one parents, this variable is useful, since the event will not begin until all parents are done. The third
variable is `setMinStartCycle`, which stores the lower bound of the event's start cycle. This variable is initialized when 
the contention-free start cycle of the event is computed in the bound phase. This variable is only used in multi-threaded
contention simulation for proper synchronization between simulation domains, as we will see later. Note that none of 
these three variables can determine when an event could start. In fact, only the completion cycle of parents and the delays 
between events determine the start cycle of the current event. 

