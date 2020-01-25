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

After all cores (not threads) finish their bound phase, the weave phase is started to simulate contention and adjust clock 
cycles of simulated cores using discrete event simulation (DES). Recall that simulated cores build event chains during the 
bound phase using the static, contention-free timing model. Static latencies represent the minimum number of cycles between 
two events, which can be "stretched" to account for contention and resource hazards. During the weave phase, all events 
from the cores are enqueued into the corresponding cycles, and then executed. At the beginning of the weave phase, only 
the earliest event is enqueued and executed. By executing an event at cycle `C`, we may add extra delay `t`, in addition 
to the static delay `D`, to the execution of its children events, if there is another event (from the same core or from 
other cores) interfering with the current event in cycle `C`. In this case, the execution of its children events will happen 
at cycle `C + D + t` rather than cycle `C + D` as in bound phase simulation. 

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
most recent uop. `curCycle` will be adjusted by the number of extra cycles introduced by contention simulation, if any, 
at the end of every weave phase. The second clock is the global Zero Load Latency (zll) clock, which is never adjusted for 
contention, and is used to represent the absolute position in the simulation timeline. The skew between the zll clock and 
the core's clock is stored as a member variable, `gapCycle`, in core recorder objects. `gapCycle` represents aggregated 
number of cycles added onto `curCycle` as a result of weave phase simulation. The zll cycle is maintained in 
`struct GlobSimInfo` as `globPhaseCycles`.

The zll clock serves as a unique reference clock for specifying time points between the bound and weave phases. The `curCycle`
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
of the weave phase. We postpone the discussion of multithreaded simulation to the end of this article. Before that, the
contention simulation is assumed to be single threaded with only a single domain.

### Memory Management

Event objects are allocated from the heap using C++ `new` operator. The base class `TimingEvent` overrides this operator,
and adds an extra `class EventRecorder` object as argument. As a result, event objects must be allocated in the form
of replacement `new`s, which looks like the following: `new (eventRecorder) EventObjectName(args)` (`eventRecorder`
is an `EventRecorder` object). This is an optimization for memory allocation and garbage collection using slab allocators 
within `EventRecorder` objects. Memory is allocated and released in large chunks to amortize the overhead of calling C
library. In addition, a chunk is only released after all event objects in the chunk are no longer used, the status of which
is tracked by a high watermark. Correspondingly, `operator delete` is not allowed to be called on event objects, since the 
slab is freed as a whole rather than individually for each event object.

The slab allocator is implemented in file phase\_slab\_alloc.h. The allocator is phase-aware, meaning that each slab (i.e. 
memory chunk) is only responsible for allocating events generated by a single bound phase (weave phase does not allocate 
events). The advantage of tagging phase numbers to slabs rather than to individual objects is that memory reclamation
becomes easier, since we do not need to scan the entire slab to determine whether the slab can be released. 

The slab object is defined as `struct Slab` within the allocator class. The object consists of a buffer, a next allocation
pointer, two variables tracking the current size and capacity repectively. Allocating from a slab is simply incrementing 
the pointer by the number of bytes requested, if free space is more than the requested size, or returns empty pointer.
`struct SlabList` implements a singly linked list that chains all slabs allocated in the same bound phase together. The
slab list provides a similar interface to standard C++ STL library, the semantics of which are straightforward. Two lists
are maintained by the slab allocator, one `curPhaseList` tracking all slab objects allocated in the current bound phase,
and a `freeList` tracking freed slabs for recycling. The allocator never return memory back to the C allocator. An extra
`liveList` tracks all slabs that are not allocated by the current bound phase, but can still be accessed. Slabs in the 
live list are tagged with the maximum zll clock in which events are allocated. The current allocating slab is tracked
by variable `curSlab`.

When an allocation is requested by calling `alloc()`, the allocator first tries `curSlab`, and if it fails, allocates
a new slab by calling `allocSlab()`. `allocSlab()` attemps to dequeue one from `freeList`, and calls system allocator
to allocate one from the global heap. The current slab is also pushed into `curPhaseList`.

When a weave phase completes, we attempt to reclaim some slabs by calling `advance()` with two arguments, both in zll clocks. 
The first argument, `prodCycle`, is the maximum cycle in the last bound phase, which is used to tag the current slab list 
for later reclamation, serving as a high water mark. After simulating events whose creation cycle is greater than the tag, 
the current slab list can be moved to the free list. The second argument, `usedCycle`, is the zll clock of the most recently 
simulated event. All slabs from previous phases whose tag is smaller than this value can be moved to the free list. 
`advance()` is called when a weave phase is completed. The caller of this method passes the zll clock of the current interval's 
end cycle as `prodCycle`, and the last simulated event's creation zll clock as `usedCycle`. This way, we maintain memory
safety by enforcing that events still accessible by future weave phases can never be released.

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

Child pointer or pointers are stored in the union structure `child` and `children`. Children events are added by calling 
`addChild()`. The member variable `state` maintains a state machine for events. An event can be in one of the following 
states: `EV_NONE` before it is enqueued; `EV_QUEUED` after it is enqueued by the parent event; `EV_RUNNING` after it is 
being simulated; `EV_HELD` when the execution of the event is delayed and it might be requeued in the future; `EV_DONE` 
when the event is done. It seems that the event state is only used in assertions for verifying event behavior, and not 
used to perform any actual change. Based on the above reason, we ignore the state variable to simplify discussion in the 
following text.

Two delay member variables, `preDelay` and `postDelay`, determine the latency between parent and child events. When a 
parent event finishes execution, child events will be notified after an extra `preDelay` cycles after the parent completion
cycle. When all parents of a child event is completed, the child event will be enqueued after an extra `postDelay` cycle
delay. In addition, for `class DelayEvent`, the `preDelay` variable also stores the static delay value.

Member function `run()` is called by the DES driver during the weave state, which performs some state transition and state 
check, and then calls `simulate()`. All derived classes of `class TimingEvent` should implement `simulate()`. This function
takes an argument `simCycle`, which is the cycle the event is simulated. Whenever an event completes execution, member
function `done()` should be called to notify children events of the completion of the parent. `done()` is called with
argument `doneCycle` which is not necessarily the same as `simCycle`. The children nodes are notified at cycle 
`doneCycle + postDelay`, as discussed above. The notification of child nodes is implemented using a template function,
`visitChildren()`, which takes a lambda function as call back. The template traverses all child nodes and invokes the call 
back on each of them. For child node notification, the call back function simply calls the `parentDone()` function of the 
event node with the cycle of notification.

The `parentDone()` in the base `TimingEvent` class is straightforward. It decrements the variable, `numParents`, which 
tracks the number of active parents, and saves the maximum parent completion time in the member variable `cycle`. If all 
parent events are completed, the event itself is enqueued into the event queue by calling `zinfo->contentionSim->enqueue()`
with an enqueue cycle `cycle + preDelay`. Here `preDelay` is the latency between last parent notification and the actual
enqueue time. 

In `class DelayEvent`, the `parentDone()` function is overridden to optimize static delays. Since the delay value is 
statically known during the bound phase, `parentDone()` will simply call `done()` with `cycle + preDelay` to recursively
incoke the `parentDone()` function of children events. This way, we do not pay the overhead of enqueuing an event and 
simulating it later, since the delay event is never inserted into the event queue. Note that although the variable name
`minStartCycle` implies that it stores the minumum cycle for an event to start, this variable is not used to determine
when an event can be inserted into the queue. In zSim, if there is a `C` cycle interval between two events on different 
simulated components, the simulator code will insert a delay event to properly model that, instead of using `preDelay` or 
`postDelay` of the two events.

### The Event Queue

The per-domain event queue is included by the global `class ContentionSim` object. `class ContentionSim` contains 
a member array `domains`, which stores thread-local data for each contention simulation thread in the weave phase. 
Each element of the object is of type `struct DomainData`, which contains a `class PrioQueue<TimingEvent, PQ_BLOCKS>`
object `pq`, a cycle variable `curBlock` tracking the absolute starting cycle of the first event's block (see below), 
and a lock, `pqLock`, to serialize threads attempting to insert into the queue during the bound phase. We postpone the 
discussion of other member variables to multithreaded contention simulation, and only focus on single threaded DES in 
this section.

The priority queue object is defined in prio\_queue.h as `class PrioQueue`. The implementation of the queue is also
overly complicated doe to optimization, just like the instruction window in out-of-order core. Events in the near future 
are stored in `struct PQBlock`, which contains a 64-element array. A 64-bit integer serves as a bit mask to indicate whether the corresponding cycle has at least one event scheduled. Events scheduled on the same cycle are chained into a singly linked 
list using the `next` pointer. The queue object tracks events in the future `64 * B` cycles in the array `blocks`, where
`B` is a template argument specifing the number of `PQBlock`s. The rest of the events are stored in a regular multimap 
object, `feMap`.

Inserting into and removing the top event from the queue is straightforward. For insertion, we compute the block offset
and the slot offset within the block, and calls `enqueue()` of the block object if the event is scheduled for the near future. 
Otherwise, we directly insert the event into the multimap `feMap`. For dequeue, we scan `PQBlock` objects to find the first 
non-empty block, and compute the offset within that block before calling `dequeue()`. If all blocks are empty, we iterate 
through `feMap` and populate the empty blocks before retry the dequeue operation. Note that the argument `deqCycle` will
be updated accordingly to the actual cycle the event is stored.

The event queue also provides a member function `firstCycle()`, which returns the absolute cycle of the nearest event in
the event queue. This function is used to probe the next event cycle, which as we will see later, is used by the DES driver
to determine when the current weave phase simulation should terminate.

The `class ContentionSim` object also provides two interfaces for inserting an event into the priority queue. The first
is `enqueueSynced()`, which acquires the per-queue lock `pqLock` before inserting the object into the queue. This method 
is called during the bound phase where application threads may insert events into each other's domain, hence creating race 
condition when two threads attempt to insert into the same domain concurrently. The other is `enqueue()`, which does not 
acquire the lock before inserting events. This method is called during the weave phase, and is only called by the thread 
reponsible for the domain. `class TimingEvent`'s two method functions, `queue()` and `requeue()`, wraps `enqueueSynced()` 
and `enqueue()` respectively.

## Weave Phase

The bound phase ends when the last core calls `TakeBarrier()` (defined in zsim.cpp). This function will further call
into the scheduler and the barrier, and finally `EndOfPhaseActions()` (defined in zsim.cpp) will be invoked to start
the weave phase. Recall that `globPhaseCycles` is the global zll clock used by zSim to uniquely specify a time point. 
We first compute the zll cycle of the end of the weave phase as `zinfo->globPhaseCycles + zinfo->phaseLength`, in which
`phaseLength` specifies the maximum number of cycles we simulate in the bound and weave phase. This value is configrable
using the option `sim.phaseLength` in the configuration file. Then we call into `zinfo->contentionSim->simulatePhase()`
to wake up weave threads, as we will see below.

### Weave Phase Thread Pool

The weave phase implements its own thread pool in contention\_sim.h/cpp. The weave phase is not run by application threads. 
Instead, zSim starts `numSimThreads` threads in the background during initialization. This number of configurable using
configuration file option `sim.contentionThreads`. Weave phase threads spawns into function `SimThreadTrampoline()`,
which assigns each thread an internal ID, `thid`, by atomically incrementing a shared counter, and then calls into
`simThreadLoop()` with the ID. Function `simThreadLoop()` implements a loop in which threads first blocks all weave phase 
threads on the thread-local lock variable `wakeLock`, and then runs the contention simulation body after they are unblocked. 
The application thread that starts the weave phase will in the meantime be blocked on another lock, `waitLock`, until 
contention simulation ends. A member variable of `class ContentionSim` notifies all weave phase threads of the end of 
simulation, which causes these threads to exit the loop and returns.

Weave phase threads runs the simulation body by calling into `simulatePhaseThread()`. After this function returns, they
atomically increment a counter `threadsDone` to track the number of completed threads. The last completed thread will find 
this value being `numSimThreads`, and will then unblock the application thread by unlocking `waitLock`. The application
thread will then return back to the scheduler, and start the next bound phase, the details of which will not be discussed.

In `simulatePhase()`, the application thread calls `cSimStart()` and `cSimEnd()` at the beginning and the end of the function
respectively to notify cores of the start and end of contention simulation. We will cover this part later. The thread
also unlocks weave phase threads by looping through the thread pool, and unblocking these threads using `futex_unlock()`.
The thread then blocks itself on `waitLock`. I am not sure whether there is a race condition on the order of `waitLock`
locking and unlocking. If the application thread is stalled by the host OS for a long time, then it is possible that
`waitLock` is unlocked before the thread is rescheduled by the host OS and then acquire the wait lock. If this happens,
the application thread may be permanently blocked on `waitLock`, which hangs the entire simulation.

### The DES Event Loop

Function `simulatePhaseThread()` implements the main event loop of weave phase DES. This function contains two independent
code paths, one for single domain simulation, the other for multi-domain simulation. zSim restricts the number of domains
to be a multiple of the number of threads, meaning that all threads must simulate the same number of domains, from
`firstDomain` to `supDomain`, both being member variables of `struct DomainData` and hence thread-local. In this section 
we only cover sing-threaded, single-domain simulation.

In the single-thread execution path, we keep taking events from the top of the priority queue, and check whether the event
cycle is within the value of `limit`. Recall that this argument is the zll clock on which weave phase should end. The 
weave phase thread enters the event loop by comparing the next event cycle with `limit` using `pq.firstCycle() < limit`.
If true, meaning that we still have events in the interval to simulate, the thread then dequeues the event using
`pq.dequeue`, and calls `run()` method of the event object, after it updates the `curCycle` of the domain to the event 
cycle. After the event loop, the `curCycle` of the domain is set to `limit` regardless of the next event in the queue
(if any). The global zll clock, `zinfo->globPhaseCycles`, is also incremented by `zinfo->phaseLength` cycles by the scheduler.

Note that the end cycle of weave phase contention simulation is zll clock cycle, not per-core cycle, since zll clock is 
globally synchronized and unique. If events generated by the previous bound phase cannot be all simulated in the current 
weave phase, we check, in the core timing model, whether the adjusted `curCycle` (due to contention in the last weave
phase) is larger than the zll clock cycle of the next interval. If true, we skip the next bound phase, and directly 
run weave phase to make sure that skews between cores at least do not increase. If not, but `curCycle` is somewhere between 
the previous and the next interval, we run the bound phase, and stop as soon as `curCycle` reaches the interval boundary.