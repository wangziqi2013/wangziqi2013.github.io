---
layout: post
title:  "Understanding Processor Microarchitecture Simulation in zSim"
date:   2019-12-31 21:57:00 -0500
categories: article
ontop: true
---

## Introduction

In the previous article, we discussed how the cache system is modeled by zSim using a coherence-centric simulation
method and the elegant cache object interface `access()` and `invalidate()`. In this article, we proceed to discuss 
microarchitecture simulation in zSim. We will put our focus on Out-of-Order core simulation, due to the complexity
of pipelined, Out-of-Order execution. We will also give a brief discussion on other types of cores, such as simple
core and timing core. 

As mentioned in the previous article, zSim is implemented as a binary instrumentation library using the PIN framework.
Simulation is started by invoking the PIN executable with the path of both the zSim library (called a "pintool") and the 
path of the application. The PIN executable then loads the application binary into memory, before it instruments the binary
using directives (called "instrumentation routines") provided by the pintool. Instructions in the simulated binary is still
executed by the native hardware, except that at certain points, such as load/store instructions, basic block boundaries, system
calls, etc., control will be transferred to the simulator for various purposes. These routines that are executed in
the run time is called "analysis routines", in which the timing model of zSim is implemented. We do not cover the details of instrumentation. Instead, in this short introduction, we concentrate on, at a high level, how the simulated application 
interacts with zSim and how controls are transferred between the simulator and the binary.

In the below table, we list the name of source files that are releted to our discussion, and a short description of the 
functionalities implemented in the file. 

| File Name (only showing headers) | Important Modules/Declarations |
|:--------------------------------:|--------------------------------|
| decoder.h | Pre-decoding and Decoding stage simulation; Instruction to uop translation; `DynBbl`, execution port definition; Register dependency definition. |
| ooo\_core.h | Out-of-Order core microarchitecture simulation, incluuding instruction fetch, instruction window, reorder buffer, loads and stores, and register file simulation. |
| zsim.cpp | Instrumentation routines for basic blocks, loads and stores, and branch instructions. | 
| core.h | Core interface for analysis routines; Core interface for simulation.  |
{:.mbtablestyle}

### Dynamic Basic Block Instrumentation

The instrumentation routine for basic blocks can be found in the `main()` function (zsim.cpp). zSim registers a call back
`Trace()` to PIN using library call `TRACE_AddInstrumentFunction()`, the effect of which is that the `Trace()` call back
will be invoked every time PIN sees an uninstrumented trace during execution. In zSim, a trace is defined as a single-entry
multiple-exit code block. Control flow could only enter the code block from the top (i.e. lowest address instruction), but
can exit the trace via branch instructions in the middle. Naturally, a trace consists multiple basic blocks, each beginning
from the termination point of the previous basic block (or the beginning of the trace), and terminates at the branch instruction
exiting the trace. Note that basic blocks and traces are recognized by the PIN framework dynamically, meaning that a dynamic 
basic block (or trace) in PIN may be broken into two smaller basic blocks (traces) if a branch instruction jumps to the 
middle of the block (trace) in the run time. In this case, each new basic block (trace) will be re-instrumented by calling 
the instrumentation routine registered to PIN, and the old instrumentation will be discarded.