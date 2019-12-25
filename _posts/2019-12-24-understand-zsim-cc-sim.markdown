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
-----------------------------------|--------------------------------|
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
