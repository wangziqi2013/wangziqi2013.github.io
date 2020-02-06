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
two events, which can be "stretched" as a consequence of contention and resource hazards. During the weave phase, all events 
from the cores are enqueued into the corresponding cycles, and then executed. At the beginning of the weave phase, only 
the earliest event is enqueued and executed. By executing an event at cycle `C`, we may add extra delay `t`, in addition 
to the static delay `D`, to the execution of its children events, if there is another event (from the same core or from 
other cores) interfering with the current event in cycle `C`. In this case, the execution of its children events will happen 
at cycle `C + D + t` rather than cycle `C + D` as in bound phase simulation. 

The weave phase may not simulate all events generated by the most recent bound phase. In fact, given an interval size of 
`I`, the weave phase will stop after the next event's start cycle exceeds cycle `S + I` where `S` is the starting cycle
of the most recent interval. This is to guarantee that the clocks of all cores will be driven forward in locksteps at 
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
phase) is larger than the zll clock cycle of the next interval. If true, we skip the next bound phase to make sure that 
skews between cores at least do not increase. If it is not the case, but `curCycle` is somewhere between the previous and 
the next interval boundaries (i.e. there is some adjustment due to contention, but the number of cycle is smaller than 
interval size), we let the bound phase run, and stop it as soon as `curCycle` reaches the interval boundary.

## Cache Contention Model

In a previous article, we discussed the static timing model of zSim cache objects. The static timing model consists of 
the cache hierarchy, the upward propagation of `PUT` and `GET` requests, and the downward propagation of invalidations.
The largest issue with the static timing model is that potentially concurrent accesses only incur fixed delay, while in 
reality, shared resources can only be accessed by a limited number of requests at a time, due to the fixed number of 
accessing circuits or buffer space (e.g. MSHR). 

The cache contention model solves concurrent access problem using various access events. These events are generated 
independently by cores accessing a cache object during the bound phase. Events generated in this stage only uses the local
clock of the core. Then, in the following weave phase(s), events from different cores are inserted into a single event queue, 
which are then executed under the unified zll clock. 

### Event Chain

Before we discuss the cache timing model, we first give a brief overview of the process in which event chains are generated.
A cache access transaction begins with an `access()` request of type `GETS` or `GETX` from the bottom level, which may 
recursively call into parent cache's `access()` method. Invalidations and put requests are generated during this process 
as a result of eviction and/or downgrading a cache block. zSim assumes that invalidations are always contention-free, 
meaning that invalidation transactions will not change the timing of access transactions as well as themselves. In the 
following sections we will see that invalidation requests will not be simulated by the weave phase contention model.

A cache transaction starting from any cache object will generate an event chain in the form of `struct TimingRecord`.
This object contains the request/response cycle and the begin/end event of the cache transaction. The event chain
is not necessarily a singly linked list where each node has only one child. Instead, some events may have two 
children events, one for starting a put transaction to write back a block to the parent cache, and another for forwarding 
the get request to the parent level. The event chain of the current level will be returned to the caller of the 
`access()` method via a global data structure, `zinfo->eventRecorders`.

Per-core event recorders are implemented in file event\_recorder.h as `class EventRecorder`. For single-domain contention 
simulation, it is just a stack of timing records, `trStack`, plus a memory allocator, `slabAlloc`, as we have seen above. 
The event recorder provides interfaces for pushing and poping a timing record, and also for accessing timing records in-place. 
Timing records objects generated by an `access()` call will be pushed into the event recorder before the `access()`
method returns to the caller. The caller will then pop the record, check its type, and extend the event chain by appending
and prepending its own access events to the event chain. The event chain grows as the process is performed recursively.
At the end of the cache hierarchy, the core model pops the final event chain from the recorder, and link them into the 
global event chain.

On each cache access, at most two recursive `access()` calls will be invoked on the parent memory object for write back 
and block fetch respectively. As discussed above, each `access()` call will push a timing record in the event recorder
of the requestor core. The caller of the `access()` method must, therefore, first check the number of records after
the recursive `access()` returns. If only one record is present, we know no write back timing record is generated, since
the only record must be generated by accessing the tag array. Otherwise, two records are present, and we link them together
(details below) into a single event chain, and push the new reocord into the event recorder, maintaining the invariant
that each `access()` will push one timing record into the per-core recorder. The `access()` method uses the `srcId` field
of the `MemReq` object to identify the requesting core and to locate the event recorder, which is first initialized by 
`class FilterCache`'s `replace()` method. 

### The Timing Cache

`class TimingCache` is a subclass of `class Cache`, defined in timing\_cache.h/cpp, which implements a weave phase contention 
model in addition to the static timing model. Timing cache overrides the `access()` method of the base class cache to 
extend the semantics of accesses. Timing cache does not model contention caused by invalidation or downgrade, and 
therefore `invalidate()` is not overridden.

The access protocol, cache coherence and the locking protocol in the timing cache remain almost the same as in the base 
class cache. The only difference is that in a timing cache, the `processAccess()` method is passed one more extra argument,
`getDoneCycle`, to return the cycle when the `bcc` finishes processing the get request, which can be the cycle the parent
cache's `access()` returns in the case of a cache miss, or the same cycle passed to this function if the request is a hit. 
In other words, this cycle represents the earliest cycle the address tag to be accessed is present in the current cache.
As a result, when we call into the parent cache's `access()` method for a get request, two response cycles are returned.
The first cycle, `getDoneCycle`, represents the time when the block is delivered by the parent cache. The second cycle,
`respCycle`, represents the time when the invalidation, if any, finishes. Note that these two can both occur, if, for example,
a `GETX` request hits a `S` state line in the cache. The request must be forwarded to the parent cache with exclusive 
permission to upgrade state by calling `access()`, and after the parent access method returns, we send invalidations to
other lower level caches to invalidate their copies of the `S` state line. zSim does not assume that these two process
can be overlapped, since in the `processAccess()` method of `class MESICC`, the `respCycle` from `bcc`'s `processAccess()`
is passed to tcc's `processAccess()` as the start cycle.

In timing cache's access() method, we first remember the initial number of records in the event recorder before we 
start the access protocol, and save it to `initialRecords`. Then, we perform locking, tag array lookup, and eviction
as in the base class cache. After the `processEviction()` returns, we check whether the number of records in the 
event recorder is `initialRecords + 1`. If true, then we have performed an `access()` call to the parent cache, resulting
in the generation of an access record. Note that the current implementation of zSim coherence controller filters out
clean write backs in the form of `PUTS`. The coherence controller will simply discard the request without calling 
`access()` on the parent, and hence there will be no timing record in this case. The eviction timing record will
be saved in local variable `writebackRecord`. The flag variable `hasWritebackRecord` will also be set to `true`.

After processing eviction, the timing cache proceeds to process access by calling `cc->processAccess()`. After 
this function returns with two cycles, we again check whether the current number of records in the event recorder
is `initialRecords + 1`. If true, we know parent `access()` is called recursively to fetch the block or to perform
a downgrade, in which case we pop the record, and save it into local variable `accessRecord` after setting `hasAccessRecord` 
to `true`.

Note that zSim only simulates cache contention and resource hazard on shared, non-terminal caches. L1 terminal cache and 
the virtual private cache must be declared to be of type `Simple` in the configuration file. This suggests that in most 
cases, cache access will not generate any event chain due to the fact that L1 filters out most traffic to shared caches.

### Connecting Events

The next step is to connect these timing records into an event chain, potentially adding extra events to account 
for the delay between access events. We first initialize a local `TimingRecord` object `tr`, and initialize this object 
using information from the current request. We leave the `startEvent` and the `endEvent` fields to `NULL`, which will
be filled later.

We first check whether the request hits on the current level by comparing `getDoneCycle - req.cycle` against `accLat`.
Recall that `getDoneCycle` is the cycle `bcc` returns, and `req.cycle` is the cycle the request is made. If the difference
between these two equals `accLat`, the only possibility is that no parent `access()` is called, neither by eviction
nor by access, because otherwise the parent cache will add an extra `accLat` in addition to the current cache. This
happens when the request hits the current level, or when the current level has the line but needs invalidation. Either
case, we compute the overall access latency, `hitLat`, as `respCycle - req.cycle`, and create a `class HitEvent` object. 
The `postDelay` of the hit event is set to `hitLat`, indicating that the tag array cannot be accessed for other purposes
from the cycle the request is received, to the cycle the tag array lookup and invalidation completes. We also set both
`startEvent` and the `endEvent` field of `tr` to the hit event, indicating that the current level is the last level
the access traverses in the hierarchy, before we push `tr` into the event recorder.

If the latency between the request receival and `getDoneCycle` is longer than the local access latency, we know parent 
`access()` must have been called, and we connect the current level's access events to the event chain generated by the 
parent level. We first create three event objects: One `class MissStartEvent` object for modeling the MSHR acquisition 
and the initial tag array lookup; One `class MissResponseEvent` object for collecting statistics and does not perform
any simulation; One `class MissWritebackEvent` object for releasing the MSHR and modeling the final tag array access
with lower priority. The second tag array is necessary, since the tag array and the coherence state of the line being
accessed needs to be updated. This is also reflected by the fact that parent cache's `bcc` modifies child cache's 
`MESIState` variable before the access method returns.

In order to connect events into an event chain, the timing cache defines an in-line lambda function `connect()`, which
takes a begin event `startEv`, an end event `endEv`, a begin cycle `startCycle`, indicating the time `startEv` happens, 
an end cycle `endCycle`, indicating the time `endEv` happens, and optionally a timing record `r` to connect to. The 
`connect()` lambda function first inserts delays between the current start event and the start event in the timing record 
`r`, if any, by computing the difference between `reqCycle` of the timing record and `startCycle`. This represents the 
time interval between `startEv` and `r->startEvent`. We then create a delay event `dUp`, whose delay value is the difference 
just computed, and connect `startEv` to the delay event. The delay event is then connected to `r->startEvent` to complete 
the first half of the event chain. Note that if the delay is zero, no delay event is created, and we directly connect 
`startEv` to `r->startEvent` instead. Similar connection is done for `endEv` and `r->endEvent`. If `r` is not provided 
(`NULL` value), we simply link `startEv` and `endEv` with a delay event of value `endCycle - startCycle` in-between. 

The actual event connection is very simple: If an access record is returned by the parent level, we call `connect()`
with the access timing record, and `MissStartEvent`, `MissResponseEvent` objects as `startEv` and `endEv` respectively. 
The `startCycle` and `endCycle` are `req.cycle + accLat` and `getDoneCycle` respectively. Note that we need of offset 
the start cycle by `accLat` cycles, since the `postDelay` of the `MissStartEvent` object already provides `accLat` delay. 
We also directly connect the `MissWriteBackEvent` object to the `MissResponseEvent` object using `addChild()`, since the 
response event does not incur any extra delay.

If eviction record is available, we also add eviction delay between `MissStartEvent` and `MissWriteBackEvent` object by
calling `connect()`. The start and end cycles are `req.cycle + accLat` and `evDoneCycle` respectively. Note that in contention
simulation, the eviction event is considered to happen in parallel with the parent level `access()` method. As a result, 
the latency of eviction is not added to the parent cache access path, but instead, as a parallel path with the access 
event chain. The MSHR can only be released after both the parent `access()` and eviction finishes.

Note that the `cands > ways` branch is irrelevant for normal timing caches. This branch takes care of the timing for 
evaluating [ZCache](https://people.csail.mit.edu/sanchez/papers/2010.zcache.micro.pdf), which is a cache organization 
proposal from MIT. Normal timing caches always have `cands` equals `ways`, meaning that the replacement candidates must
be only from the same way as the new line to be inserted. 

### Simulating MSHR

Miss Status Handling Register (MSHRs) buffer the status of outstanding cache accesses, no matter whether the access is a 
cache hit or miss. There are only a limited number of MSHRs on real hardware, which may incur resource hazards when multiple 
requests are processed in parallel. If MSHRs become the bottleneck, entries in the load/store queue will be stalled until 
a MSHR is released. zSim models MSHR and the stall effect by postponing the execution of MSHR acquisition events, as we 
will see below.

`HitEvent`, `MissStartEvent` and `MissWriteBackEvent` collaboratively simulate MSHR using a member variable of `class TimingCache`,
`activeMisses`. When a `MissStartEvent` or `HitEvent` is simulated, we first check whether `activeMisses` equals `numMSHRs`,
another member variable of `class TimingCache` which is initialized from option `mshrs` in the configuration file. If true,
the miss start event cannot be simulated at the current cycle, in which case we simply call `hold()` to change the state
of the event to `EV_HELD` (recall that states are only used for assertion), and then insert it into `pendingQueue`. The 
`pendingQueue` is nothing more than a list of events that are currently held waiting for MSHRs. 

When `MissWriteBackEvent` is simulated at cycle `C`, if the tag update succeeds (see below), concluding the cache access, 
we decrement `activeMisses` by one, which releases the MSHR being used by the current request. Then we iterate over 
the pending queue, and re-insert all cache access start events held waiting for MSHR into cycle `C + 1`. This is 
equivalent to blocking all pending requests until one MSHR is released by a prior request.

### Simulating Tag Lookup

zSim assumes that the cache tag access circuit can only support one access on each cycle. Although each tag access may
take more than one cycles (depending on `accLat`), it is assumed that the access process is pipelined, such that one 
request can be processed each cycle. The tag access simulation needs to detect race conditions where more than one 
access is requested, and postpone all but one requests to later cycles. 

Recall that the tag array needs to be accessed twice for every miss access. One for the tag array lookup to determine if 
the request hits a line in the current cache. The second access happens after the parent cache responded to update
the address tag and/or the coherence state. Cache hits, on the other hand, only access the array once at the beginning.
zSim treats tag array lookup operation as high priority, and tag array update operation as low priority. High priority 
accesses will be queued for a future cycle in the order they arrive, if they can not be fulfilled immediately. Low priority 
accesses, on the other hand, are not queued with high priority ones for guaranteed completion. Instead, they are only 
processed when the access circuit is idle. Starvation may happen temporarily to low priority accesses if requests keep 
coming to the cache. This, however, will not lead to a permanent starvation, since no more high priority requests will 
be handled after all MSHRs are occupied.

The timing cache provides two methods, `highPrioAccess` and `tryLowPrioAccess`, for modeling high and low priority accesses 
respectively. `highPrioAccess` returns the cycle of completion of high piriority accesses, while `tryLowPrioAccess` may
return zero indicating that the low priority access must wait until a future cycle in which no high priority access is
pending. This future cycle cannot be known in advance. Imagine that if we schedule a low priority access at a future cycle 
`F`, which is the nearest idle cycle at the time the access event is processed at cycle `C`. If another high priority 
access is processed after `C` but before `F`, then the high priority access must be scheduled at cycle `F`, which makes 
the previous scheduling of the low priority event invalid. 

In order to model the queuing effect of high priority accesses, the timing cache maintains a member variable `lastAccCycle`,
to represent the scheduling cycle of the last high priority access. When a high priority access event is processed,
it compares the simulation cycle `C` with `lastAccCycle + 1`. If the latter is larger, then the event must be queued for
`lastAccCycle - C` cycles before it is handled by hardware.

The timing cache also tracks the current "interval" of busy cycles using a member variable `lastFreeCycle`. An interval
of busy cycles will form if we schedule one access right after the other. This can be a result of queuing requests and 
schedule them in the future, or just lucky timing (i.e. an event arrived just after the last one is finished and there
is no pending request). There are two possibilities when we schedule a high priority access. In the first case,
`lastAccCycle + 1` is larger than simulation cycle `C`, meaning we must queue the current request to the future cycle
`lastAccCycle + 1`, and there will be no free cycle between the previous tag access and the current one.
In the second case, `lastAccCycle + 1` is smaller than simulation cycle `C`, in which case there is at least one free 
cycle between the last and the current access. We update `lastFreeCycle` to `C - 1` to indicate that there is a free 
cycle at time `C - 1` that can be used to probably schedule a low priority event, regardless of what happens in the future.

When a low priority access is simulated at cycle `C`, the access can be processed immediately if one of the two following 
holds. First, if `C` is no smaller than `lastAccCycle + 1`, meaning that the tag access circuit is currently idle at cycle
`C`, then the low priority access can be granted. In the actual code, all cycles are moved backwards by one (minus one) 
for reasons that we will discuss below, but the essence does not change. In this case, we also update `lastAccCycle` to 
`C` to indicate that future requests can only start from at least `C + 1`. 

Second, if the first check fails, we then seek to schedule the low priority access at cycle `C - 1` by comparing 
`lastFreeCycle` and `C - 1`. If these two are equal, then we take the free cycle by setting `lastFreeCycle` to zero,
indicating that it cannot be used for scheduling another low priority access. Note that this slightly violates the 
philosophy of DES, since we schedule an event "into the past" at cycle `C - 1` when the event itself is only executed 
at cycle `C`. zSim author claims that such slight change of timing will not affect simulation result, since the 
low priority access is often not on the critical path, but this simplifies scheduling of low priority events, since
an event scheduled into the past will never be affected by any future decision. This is also the reason why we move the 
simulation cycle forward by one cycle even if the access circuit is idle. 

If neither condition is met, `tryLowPrioAccess` returns zero, and the low priority access will be re-enqueued at the next
cycle to re-attempt access. Note that there is no pending queue for low priority accesses, since the condition of 
unblocking a low priority access can only be known after a free interval is created.

## Timing Core Contention Model

The core contention model consists of two aspects. The first aspect is bound and weave phase scheduling, which interleaves
these two phases in a way such that inter-core skews are minimized. The second aspect is clock adjustment and event chain
maintenance. We cover these two aspects in the following sections.

### Bound-Weave Scheduling

zSim schedules bound and weave phases after it has finished simulating a basic block. The scheduling decision is made
in basic block call back fuction of the core. For `class TimingCore`, the function is `BblAndRecordFunc()`, while
for `class OOOCore`, the function is `BblFunc()`. Other core types do not support weave phase timing model, and hence
does not need the scheduling function.

The core object maintains a variable `phaseEndCycle`, which is nothing more than a copy of the zll clock. Every time 
after we made a scheduling decision, this clock is incremented by the interval size, `zinfo->phaseLength`, indicating 
that the core enters the next interval. When a basic block finishes simulation in the bound phase, we check whether 
`curCycle` is larger than or equal to `phaseEndCycle`. If negative, this function returns, giving the control flow back 
to the application code. If the condition is true, meaning that we have already simulated more cycles than the interval 
size in the contention-free bound phase, the weave phase will be scheduled to simulate contention. As we have discussed
above, the core calls `TakeBarrier()`, blocking itself until all other cores finish their bound phases, after which the
weave phase threads are waken up to perform DES.

When the weave phase completes, the core adjusts its local clock `curCycle` to accommodate extra delays caused by contention.
The weave phase will stop as soon as the next event's start cycle is larger than the end of the current interval, possibly 
leaving some events generated by the bound phase behind for the next weave phase. After `TakeBarrier()` returns, assuming
no context switch, we compare `curCycle` after adjustment with the end cycle of the next interval,`core->phaseEndCycle`. 
If `curCycle` is even larger than the end cycle of the next interval, meaning that the core has already been running "to 
far ahead" into the future compared with the global zll clock, then we slow it down a little by skipping the next bound 
phase. In this case, execution of the next basic block will be postponed, and the core simply trap itself into the barrier 
by calling `TakeBarrier()` again after incrementing the core's `phaseEndCycle`. This process may be repeated for a few 
intervals, until the `curCycle` is finally less than `phaseEndCycle`. 

Note that the scheduling of bound and weave phase is only an attempt from the core to minimize clock skews among cores.
Unbounded skew can still be introduced, for example, if the core simulates a long basic block (or memory access) which 
advances the `curCycle` by `k > 1` intervals, the clock skew between the core and other cores can be arbitrarily large 
depending on the size of the basic block (or the length of the memory access). The same worst case happens if an event 
introduces a delay of `k > 1` intervals, although very unlikely since the static delay should be modeled in the bound 
phase.

### Core Recorder

The core itself also maintains an event chain, which connects all memory accesses made by the core in the order that they
are performed. The core may also add extra events to ensure proper ordering of actions within its pipeline, or to track
the progress of weave phase contention simulation. In this section we discuss the event chain of `class TimingCore`, which 
is relatively simpler. We discuss the more complicated event chain of `class OOOCore` in the next section. 

Recall that timing cores assume IPC = 1 except for memory instructions. Memory instructions invoke cache `load()` and 
`store()`, which simulates both static timing and contention if the core is connected to timing caches. In `class TimingCore`, 
function `loadAndRecord()` and `storeAndRecord()` perform memory operation. In addition to calling the underlying filter 
cache's methods, these two functions invoke the core recorder, `cRec`, to connect the event chain produced by the access, 
if any, onto the core's event chain. 

The core recorder object `cRec` is of type `class CoreRecorder`, defined in core\_recorder.h/cpp. Its member function
`record()` is called every time after a `load()` and `store()` returns. This function checks the per-core event recorder
(note that event recorder is not the core recorder). In most cases, the access will either hit the filter cache or the 
private L1 cache, which does not generate any event chain, as we have discussed above. If, however, the request misses 
the L1 cache, then two possibilities might occur. In the first case, the L1 cache fetches a block from the L2 by calling 
`access()`, without an eviction. In this case, there would be only one timing record in the event recorder, which is of 
type `GETS` or `GETX`. In the second case, the L1 first evicts a block to the L2 by calling `access()`, and then fetches 
the target block from the L2 by calling `access()` again. The L1 itself will not connect these two event chains, since L1
caches are always non-timing cache. Recall that the event recorder behaves like a LIFO stack, and that the cache access 
protocol always evicts a line before the new line is fetched. In this case, we know the top of the timing record stack 
must be a `GETS` or `GETX` record, and the stack bottom is a `PUTS` (impossible for inclusive caches) or `PUTX` record. 
In both cases, `record()` will call `recordAccess()` to handle the event chain.

The core recorder maintains several variables for tracking the status of the previous cache access's event chain.
Member variable `prevRespEvent` points to the last event object of the most recent event chain generated by a cache access. 
The event chain generated by the next cache access will be connected to this last object, with some delay in between.
`prevRespCycle` is the cycle in which `prevRespEvent` happens. During the bound phase, this variable represents the cycle 
the event is supposed to happen without contention. This variable will be adjusted after the weave phase to reflect the effect of contention.

To track the progress of weave phase contention simulation, the core recorder also maintains a variable `lastEventSimulated`
which points to the last `TimingCoreEvent` object simulated during the most recent weave phase. The `TimingCoreEvent` 
stores the zll clock in which it is generated and linked into the core event chain, in member variable `origStartCycle`. 
When the event is simulated, it also stores the actual start cycle in member variable `startCycle`. We can therefore 
compute the extra number of cycles incurred by taking the difference between `startCycle` and `origStartCycle + gapCycle`,
where `gapCycle` is the skew between the zll clock and the core's `curCycle` as we have discussed at the beginning of 
this article. Besides, a timing core event also incurs a delay between the two events before and after it. This feature
is used to model the static time period between two memory accesses. The event itself does not incur any extra delay, though.

Note that whenever we need to specify a bound phase time point that will be possibly referred to in a later phase, we should 
either use the zll clock to represent the time point, or adjust the value after each weave phase as `curCycle` is adjusted. 
For example, in the above discussion, `prevRespCycle` is adjusted every time `curCycle` is adjusted, which is easy to
do since they are both member variables of the core. For `origStartCycle` in `TimingCoreEvent` objects, however, we use 
the zll clock ather than the logical core clock. The reason is that If the core's logical clock were used, the `origStartCycle` 
would need to be updated also as the core adjusts its `curCycle`, because events generated in a bound phase may not be 
all simulated in the next weave phase due to some events being enqueued into cycles belonging to the next interval.
This would suggest that the core should track and update all `TimingCoreEvent` objects it has generated but not yet simulated, 
which is more complicated than simply using the zll cycle.

### Core Event Chain

The core recorder's method `recordAccess()` first checks the stack bottom to determine whether an eviction record is present
in addition to the access record. Note that the function argument `startCycle` is the cycle the cache access is started, 
rather than the response cycle. If the stack bottom is of type `PUTS` or `PUTX`, we know there is one more record above 
it, which is of type `GETS` or `GETX`. We compute the delay between the current access and the end event of the previous 
access using `startCycle - prevRespCycle`, given that `prevRespCycle` is the bound phase cycle of the last event in the 
previous event chain. We then create a new `TimingCoreEvent` object `ev` with the delay value being what has been computed right
above. The `origStartCycle` of the event is set to `prevRespCycle - gapCycles`, meaning that the event logically happens 
in the same cycle as `prevRespCycle`. We then connect `ev` to both the put and get access event chain, via two delay
events `dr` and `dr1` respectively. The delay values are simply the difference between the request begin cycle and 
`startCycle`. In the last step, we update both `prevRespEvent` and `prevRespCycle` to the event object and the bound phase
cycle of the last event in the access event chain, respectively. The eviction event chain will not be connected to any 
later events. They are only simulated to model contention with access events. The event recorder is also cleared after
events are connected.

If only an access record is in the core recorder, then we connect the access record after `prevRespCycle` in the same 
manner as described above using `TimingCoreEvent` and delay events. The only difference is that the `TimingCoreEvent`
object has only one child, instead of two.

Note that weave phase simulation progress is only reported when a `TimingCoreEvent` object is executed, which is inserted 
only at cache event chain boundaries. This implies that we do not know the progress of simulation within the event chain 
of a cache access. In other words, if the weave simulation terminates while it is inside the event chain of a cache access, 
events that are after the most recently simulated `TimingCoreEvent` object will not be reported. This implies that 
`lastEventSimulated` actually points to the last `TimingCoreEvent` simulated, rather than the last event.

### The First Event Ever Simulated

In the previous discussion, we assumed that there is always a previous event chain, the last event of which is pointed 
to by `prevRespEvent`. This may not always be true without special care being taken, since if a weave phase exhausted all 
events in the core's event chain, then during the next bound phase, `prevRespEvent` will be undefined. This issued can 
be solved as long as the core always create an artificial placeholder event that is guaranteed not to be simulated by the 
weave phase right before it starts, and move `prevRespEvent` to point to that event (which is indeed what zSim does; see 
below). The question is, when the simulator is just started, which event should we use as `prevRespEvent`?

In fact, PIN intercepts the request when application threads are spawned. These threads will call `notifyJoin()` of the 
core recorder for first-time initialization (this function is also called on other occasions, but we ignore them for now).
Cores are initialized at `HALTED` state. `notifyJoin()` creates a `TimingCoreEvent` of zero delay, and sets `prevRespEvent` 
to the event object. This event is then inserted into the queue by calling `queue()`. After this point, as long as the 
core does not leave the scheduler barrier by calling `notifyLeave()`, it is guaranteed that at least one event of the 
core event chain is in the queue, the completion of which will drive the simulation forward. As a result, the timing event 
method `queue()` never needs to be called during normal operation.

### Contention Simulation Start and End

In this section we cover how weave phase starts and ends with the core event chain. We do not cover join/leave meahcnism
of the thread scheduler, which is essentially a technique to avoid deadlocks on blocking system calls. We also disregard 
the core state machine, since it is unrelated to normal execution. In the following discussion we assume the core state 
is always `RUNNING`, and that `notifyJoin` and `notifyLeave()` are never called after thread initialization.

Before weave phase starts, the core function `cSimStart()` is called by `class ContentionSim`'s method function, 
`simulatePhase()`. Similarly, `cSimEnd()` is called after the weave phase completes. In `cSimStart()`, the core recorder
concludes the current bound phase by inserting a `TimingCoreEvent` at `curCycle` with delay `curCycle - prevRespCycle`. 
Logically speaking, this timing core event starts at `prevRespCycle` reporting the simulated cycle of the last event in 
the most recent cache access event chain. `prevRespEvent` and `prevRespCycle` are updated accordingly. Then, the core 
reocrder inserts a second `TimingCoreEvent` after the previous one, at `curCycle` (by setting delay to zero). This event
is guaranteed not to be simulated in the incoming weave phase, since `curCycle` is already larger than or equal to the 
interval end cycle at this stage. The second timing core event is added to maintain the invariant that at least one event 
must be in the event queue during normal operatio, in order to avoid calling `queue()` except in `notifyJoin()`.
`prevRespEvent` is also updated to the newly added event.

Note that even though we insert a timing core event at the end of the interval, it is not guaranteed to be executed
during the incoming weave phase. This can happen if contention simulation incurs extra delay on the event chain. In this case,
the simulation might stop before it executes the timing core event orignally inserted at `prevRespCycle`, since this cycle 
might now be larger than the end of interval cycle on zll lock due to contention delay. As a consequence, the core recorder 
will not be reported to in the current weave phase, which may cause underestimation of the clock adjustment value. This
will happen if events between the last `TimingCoreEvent` simulated by the weave phase and the one inserted at the interval 
end also incur extra delay due to contention.

After the weave phase, `cSimEnd()` is called with `curCycle` of the core. We compute the clock skew by subtracting the 
original start cycle relative to `curCycle`, `lastEventSimulated->origStartCycle + gapCycles`, from the actual cycle it 
is simulated, which is `lastEventSimulated->startCycle`. The skew is then added onto `curCycle`, `gapCycles` and `prevRespCycle`
respectively for clock adjustment. Garbage collection is performed by calling `advance()` on the per-core event recorder
as we have discussed above.

## OOOCore Contention Model

To be continued...

## Multi-Domain Contention Simulation

To be continued...