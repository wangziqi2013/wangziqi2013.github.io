---
layout: post
title:  "Understanding Cache System Simulation in zSim"
date:   2019-12-24 20:04:00 -0500
categories: article
ontop: true
---

## Introduction

zSim is a fast processor simulator used for modeling the bahavior of memory subsystems. zSim is based on PIN, a binary
instrumention tool that allows programmers to instrument instructions at run time and insert customized function calls.
The simulated application is executed on native hardware, with zSim imposing limited control only at certain points 
during the execution (e.g. special instructions, basic block boundaries, etc.). In this article, we will not provide 
detailed description on how zSim works on the instrumentation level. Instead, we isolate the implementation of zSim cache 
subsystems from the other parts of the simulator, and elaborate on how the simulated cache is architected and how timing 
is computed. For more information about zSim, please refer to the 
[original paper](http://people.csail.mit.edu/sanchez/papers/2013.zsim.isca.pdf) which gives a rather detailed description
of the simulator's big picture. And also, it is always best practice to read the official 
[source code](https://github.com/s5z/zsim) when things are unclear. In the following sections, we will use the official
source code github repo given above as the reference when source code is discussed. 

## Source Files

Below is a table of source code files under the /src/ directory of the project that we will be talking about. For each file
we also list its important classes and declarations for reader's convenience. One thing that worth noting is that a file is not
always named using the name of the class defined within that file. If you are unsure where a class is defined, simply doing
a `grep -r "class ClsName"` or `grep -r "struct ClsName"` will suffice for most of the time.

| File Name (only showing headers) | Important Modules/Declarations |
|----------------------------------|--------------------------------|
| memory\_hierarchy.h | Coherence messages and states declaration, BaseCache, MemObject, MemReq |
| cache\_arrays.h | Tag array lookup and replacement policy |
| cache.h | Actual implementation of the cache class, and cache operations |
| coherence\_ctrls.h | MESI coherence state machine and actions |
| init.h | Cache hierarchy and parameter initialization |

Note that zSim actually provides several implementations of caches, which can be selected by editing the configuration file. 
The most basic cache implementation is in cache.h, and it defines the basic timing and operation of a working cache, and 
no more. A more detailed implementation, called `TimingCache`, is also available, which adds a weave phase timing model 
to simulate cache tag contention (zSim simulates shared resource contention in a separate phase after running the simulated 
program for a short interval, assuming that path-altering interferences are rare). In this article, we focus on the functionality 
and architecture of the cache subsystem, rather than detailed timing model and discrete event simulation. To this end, we 
only discuss the basic cache model, and leave the discussion of timing cache to future works.

## Cache Systems Interface

In this section we discuss cache subsystem interfaces. In zSim, all memory objects, including cache and memory, must inherit 
from the virtual base class, `MemObject`, which features only one neat interface, `access()`. The `access()` call takes 
one `MemReq` object as argument, which contains all arguments for the memory request. The return value of the base cache 
`access()` call is the finish time of the operation, assuming no contention (if contention is not simulated, then it is 
the actual completion time of the operation, as in our case). 

Cache objects also inherit from the base class, `BaseCache`, which itself inherits from `MemObject`, and defines another 
interface call, `invalidate()`. This function call does not take `MemReq` as argument, but instead, it takes the address 
of the line, the invalidation type, and a boolean flag pointer to indicate to the caller whether the invalidated line is 
dirty (and hence a write back to lower level cache is required). Note that in zSim, the `invalidate()` call only invalidiates
the block in the current cache object, and indicates to the caller via the boolean flag whether a write back is induced 
by the invalidation. It is therefore the caller's responsibility to write back the dirty block to the lower level using
a PUTX transaction, as we will see below. The return value of `invalidate()` is also the response time of the operation.

Overall, the cache object interface in zSim is rather simple: `access()` implements how the cache handles reads and 
writes from upper levels. `invalidate()` implements how the cache handles invalidations from the processor or lower levels
(depending on the position of the cache object in the hierarchy). Both methods are blocking: A begin time (absolute cycle 
number) is taken as part of the argument, and a finish time is returned as the cycle the operation completes.

## MemReq object

The `MemReq` object is used in two scenarios. First, an external component (e.g. the simulated processor) may issue a 
memory request to the hierarchy by creating a `MemReq` object before it calls the `access()` method (in zSim, we have an
extra level of `FilterCache`, in which case the `FilterCache` object issues the request). The caller of `access()` function
needs to pass the address to be accessed (`lineAddr` field) and the begin cycle (`cycle` field) of the cache access. The 
type of the access in terms of coherence is also specified by initializing the `type` field. In this scenario, no coherence 
state in involved, and the access type can only be `GETS` or `GETX`. In the second scenario, an upper level cache may
issue request to lower level caches to fulfill a request processed on the upper level. For example, when an upper level
cache evicts a dirty block to the lower level, it must initiate a cache write transaction by creating a `MemReq` object
and making it a `PUTX` request. In addition, when a request misses the upper level cache, a `MemReq` object must be
created to fetch the block from lower level caches or degrade coherence states in other caches. The process can be
conducted recursively until the request reaches a cache that holds this block or has full ownership, potentially reaching
beyond the LLC and reading from the DRAM. An interesting design decision in zSim is that when upper level cache issues
a request to the lower level cache, the coherence state of the block in the upper level cache is determined by the 
lower level cache controller. This design decision is made to simplify the creation of "E" state, which requires information
held by the lower level cache (i.e. the shared vector). As a result, when upper level caches issue the request, it 
must also pass a pointer to lower level caches such that the latter can assign the coherence state of the block when
the request is handled. This pointer is stored in the `state` field of the `MemReq` object. 

We summarize the fields and their purposes in the tables