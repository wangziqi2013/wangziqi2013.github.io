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
| zsim.cpp | Instrumentation routines for basic blocks, loads and stores, and branch instructions. | 
| decoder.h | Pre-decoding and Decoding stage simulation; Instruction to uop translation; `DynBbl`, execution port definition; Register dependency definition. |
| core.h | Core interface for analysis routines; Core interface for simulation.  |
| ooo\_core.h | Out-of-Order core microarchitecture simulation, incluuding instruction fetch, instruction window, reorder buffer, loads and stores, and register file simulation. |
{:.mbtablestyle}

### Dynamic Basic Block Instrumentation

The instrumentation routine for basic blocks can be found in the `main()` function (zsim.cpp). zSim registers a call back
`Trace()` to PIN using library call `TRACE_AddInstrumentFunction()`, the effect of which is that the `Trace()` call back
will be invoked every time PIN sees an uninstrumented trace during execution. This instrumentation routine provides directives
on how the trace should be instrumented (e.g. where to insert extra function calls, and which calls to insert). zSim monitors
the control flow (by inserting its own private instrumentations), and will redirect branch instructions such that 
instrumented code blocks will be executed instead of the original. This instrument-once scheme avoids the overhead of 
re-instrumentation when instructions are revisited regularly.

In PIN, a trace is defined as a single-entry multiple-exit code block. Control flow could only enter the code block from 
the top (i.e. lowest address instruction), but can exit the trace via branch instructions in the middle. Naturally, a trace 
consists multiple basic blocks, each beginning from the termination point of the previous basic block (or the beginning 
of the trace), and terminates at the branch instruction exiting the trace. Note that basic blocks and traces are recognized 
by the PIN framework dynamically, meaning that a dynamic basic block (or trace) in PIN may be broken into two smaller basic 
blocks (traces) if a branch instruction jumps to the middle of the block (trace) in the run time. In this case, each new 
basic block (trace) will be re-instrumented by calling the instrumentation routine registered to PIN, and the old instrumentation 
will be discarded.

In function `Trace()`, we iterate through all basic blocks contained in the trace, and calls `BBL_InsertCall()` to inject 
analysis routine `IndirectBasicBlock()` before the basic block is executed, which will be called at runtime. We also
simulate instruction decoding statically for the current basic block by calling `Decoder::decodeBbl()`. This function
returns a `struct BblInfo` object, which is passed to the analysis routine `IndirectBasicBlock()` for dynamic simulation.
Note that at this time, the basic block has not been executed yet, and the static decoder can only output decoder timings
independent from: (1) the decoding and execution of previous basic blocks; and (2) the actual timing of the dynamically 
simulated pipeline. In the following discussion, we will see that the decoder uses relative cycle starting from zero 
when it simulates decoding on the basic block, and that the pipeline will translate such relative cycle to the actual cycle.

### Instruction Instrumentation

Individual instructions in basic blocks are also instrumented by `Trace()` using `Instruction()`. For each instruction 
in each basic block, `Instruction()` is called to determine whether the instruction will be instrumented and which type
of instrumentation is injected. In an unmodified version of zSim, we instrument instructions that access memory by injecting
`IndirectLoadSingle()` and `IndirectStoreSingle()` before them. Note that if an instruction accesses multiple memory locations, 
or both loads from and stores into memory, multiple instrumentations will be injected for the same instruction. In the following 
discussion, we will see that load and store call backs does nothing more than simply logging the address of loads and stores, 
which serves as the basis of memory system simulation. Predicated loads and stores are also instrumented in a similar way,
but we do not cover them in this article (and in practice they are rare). We also instrument branch instructions by injecting 
`IndirectRecordBranch()` before them. This call back also just logs the target address and branch outcome (taken or not 
taken) for branch prediction simulation. Unsupported instructions (often implemented by prefixing a special no-op as "magic 
op"), virtualized instructions (those that must be emulated to hide the simulator or to change the bahavior, such as CPUID 
and RDTSC) and simulator hints are also injected in `Instruction()`. In general, the flexibility of instruction instrumentation 
enables much opportunity for third-party customization and extension.

### Core Interface

The core interface is defined in core.h. Two important data structures are defined in this header file. The first is 
`struct BblInfo`, which stores information of a basic block, such as the size, number of instructions, micro-ops (uops), 
and their relative decoder cycles. The last two are only used for Out-of-Order core simulation, and will not be generated 
for other core types. Note that `BblInfo` (and the `DynBbl` it contains) is generated during instrumentation stage when 
PIN first sees the basic block, rather than analysis stage when the instrumented code block is executed during run time. 
This implies that as long as a basic block does not change (e.g. it might be broken down into smaller basic blocks if 
control flow transfers to the middle of the block during execution), it is only decoded once, and the same decoder timing 
is reused across multiple executions of the same block. When a basic block is about to be executed, the `BblInfo` struct 
will be passed to the core via the `IndirectBasicBlock()` interface.

The second data structure is `struct InstrFuncPtrs`, which stores analysis routine function pointers. During initialization,
each core type creates an instance of `struct InstrFuncPtrs`, and populates this structure with its own static member functions.
zSim stores the current instance being used in a global structure, `InstrFuncPtrs fPtrs[MAX_THREADS]`, which is defined in zsim.cpp.
Note that each thread has a private copy of this struct, since zSim also uses this extra level of indirection to implement
per thread features, such as system call virtualization and fast forwarding. We list fields of `struct InstrFuncPtrs` and 
their descriptions in the following table.

| Field Name | Description | Core Method Called (`OOOCore`) |
|:--------------------------------:|--------------------------------|---|
| loadPtr | Called before instructions that read from memory for each operand | `OOOCore::LoadFunc()` |
| storePtr | Called before instructions that write into memory for each operand | `OOOCore::StoreFunc()` |
| bblPtr | Called before a basic block is about to be executed | `OOOCore::BblFunc()` |
| branchPtr | Called before control flow instructions, including conditional and unconditional branches | `OOOCore::BranchFunc()` |
| predLoadPtr | Called before predicated load instructions for each operand | `OOOCore::PredLoadFunc()` |
| predStorePtr | Called before predicated store instructions for each operand | `OOOCore::PredStoreFunc()` |
| type | Type of the instance; Could be one of the `FPTR_ANALYSIS`, `FPTR_JOIN` or `FPTR_NONE` | N/A |
{:.mbtablestyle}

These analyais routines only perform simple bookkeeping except `OOOCore::BblFunc()`. `OOOCore::LoadFunc()` and `OOOCore::StoreFunc()`
call `OOOCore::load()` and `OOOCore::store()` respectively, which log the memory access address into an array, `loadAddrs`
and `storeAddrs`. These addresses will be used for cache system simulation after the current basic block has finished
execution. Similarly, `OOOCore::PredLoadFunc()` and `OOOCore::PredStoreFunc()` log the addresses of predicated memory
accesses if the condition evaluates to true, or -1 if false. `OOOCore::BranchFunc()` log the branch outcome, the taken
and not taken address, and the address of the branch instruction itself by setting fields `branchTaken`, `branchTakenNpc`,
`branchNotTakenNpc` and `branchPc`. Only one entry for branch logging is required, since according to the definition, 
branches will only occur as the last instruction of a basic block.

We list important fields of `class OOOCore` and their descriptions in the following table.

| `OOOCore` Field Name | Description |
|:--------------:|-----------|
| l1i | L1 instruction cache; This cache is of `class FilterCache` type, which simulates the timing of private caches with less overhead than `class Cache` objects.  |
| l1d | L1 data cache; This cache is of `class FilterCache` type, which simulates the timing of private caches with less overhead than `class Cache` objects. |
| phaseEndCycle | The current bound phase end cycle; Used in bound-weave execution of threads to improve simulation accuracy. Not covered in this article. |
| curCycle | Current issue cycle, i.e. the cycle that the most recently simulated uop enters instruction window. |
| regScoreboard | An array of register available cycles. Used to model data flow dependency between instructions. |
| prevBbl | The current basic block that just finished execution when `OOOCore::bbl()` is called (name is misleading). |
| loadAddrs | Addresses of memory load accesses within the current basic block. |
| storeAddrs | Addresses of memory store accesses within the current basic block. |
| loads | Current number of memory load accesses (used to index loadAddrs) |
| stores | Current number of memory stores accesses (used to index storeAddrs) |
| lastStoreCommitCycle | The commit cycle of the most recent store uop. This is used to model fence. |
| lastStoreAddrCommitCycle | The commit cycle of address computation uop of the most recent store uop. This is used to model fence, data dependency of store uops, and load-store forwarding. |
| loadQueue | Load address queue. Models queue contention. |
| storeQueue | Store address queue. Models store contention. |
| curCycleRFReads | Register file reads in the current cycle. Models register file bandwidth. |
| curCycleIssuedUops | Instructions issued to the window in the current cycle. Models instruction issue bandwidth. |
| insWindow | Instruction window for buffering instructions that have not yet been dispatched. |
| rob | Reorder buffer. Models reorder buffer contention. |
| branchPred | Branch predictor. |
| branchTaken | Whether the branch in the current basic block is taken or not. |
| branchTakenNpc | The next fetch address if the branch instruction is taken. |
| branchNotTakenNpc | The next fetch address if the branch instruction is not taken. |
| decodeCycle | The decoder cycle of the most recent uop. Models decoder bandwidth limit. |
| uopQueue | The uop queue between decoder and the instruction window. Models the uop queue in Nahelem microarchitecture. |
| fwdArray | An direct-mapped array of store addresses. Models store-load forwarding. |
| cRec | Core recorder for weave phase timing model. Not covered. |
| addressRandomizationTable | Randomizes page addresses. Models virtual to physical mapping (since zSim can only see virtual addresses, but in practice the cache system uses physical address). |
{:.mbtablestyle}

### Microarchitecture Documentation

Since Intel has never published any detailed description of its microarchitecture, most of the details can only be obtained
via experimentation (timing measurements) and educated guesses. One extremely useful resource of microarchitectural documents
is [Agner's Blog](https://www.agner.org/optimize/), in which the structure of the pipeline and micro-op (uop) maps are described
in detail. zSim also uses materials in this blog as a reference. If you are uncertain about why a microarchitectural parameter 
is modeled in a particular way, it is suggested that you use the mentioned blog as the ultimate reference.

## Decoder Simulation

As discussed in previous sections, the decoding stage is simulated when PIN instruments a new basic block. The decoder 
timing information is stored as relative cycles, beginning at cycle zero, which will be expanded to actual cycles of the 
microarchitecture during dynamic simulation. For each basic block, the decoding stage is only simulated once, and stored
for later execution. This technique eliminates the overhead of decoding the basic block every time it is executed, except
for the first time, which can result in better simulation throughput. The decoder implementation is in decoder.cpp. The entry 
point of the decoder is `decodeBbl()`.

### Micro-Ops

zSim is designed to model microarchitectures similar to Core2 and Nahalem, in which x86 instructions are decoded into
RISC-like micro-ops (uops). One instruction can be translated into multiple uops if the instruction conatins several
computation that cannot be executed by a single function unit. For example, for a store instruction, there are two
steps involved: address computation and the actual store. The decoder will correspondingly translate the store instruction 
into two uops, the first using the address generation unit to calculate the store address and store it into an 
internal temporary register, and the second will read the temporary register before executed by the store unit. These two
uops must be executed respecting the data flow order, and retired in the reorder buffer atomically.

The data structure for uops is `struct DynUop`, which is defined in decoder.h. Just like a RISC instruction, an uop contains
source and destination registers. These registers can be architectural registers or internal temporary registers for uops
to store intermediate results, and they are used to model data-flow dependencies in out-of-order execution. Note that zSim 
does not model register renaming, i.e. uops directly use architectural register to establish dependencies. This may introduce 
unnecessary data flow dependencies, as shown by the below example:
{% highlight assmebly %}
1 | mov eax, ebx
2 | mov [esi], eax
3 | mov eax, ecx
4 | mov [edi], eax
{% endhighlight %}

In this example, if regster `eax` is not renamed, then instruction 1, 2, 3, 4 must be executed serially, since they form 
RAW, WAR, and RAW dependencies respectively. If, on the other hand, `eax` is renamed, then instruction 1, 2 can be executed 
out-of-order against instruction 3, 4, since `eax` will be renamed to a different register, and the WAR between instruction 
2 and 3 can be eliminated. By not allowing instruction 1, 2 and 3, 4 to be issued in parallel, zSim may slightly underestimate 
IPC. It is, however, also expected that such instruction sequence will be eliminated by an optimizing compiler already, 
and hence does not introduce too much error in the simulation result.

Uops also have a statically determined latency, which describe the number of cycles it takes to execute the uop after it 
is dispatched to the functional unit. The port mask is a 8-bit flag array indicating which ports could the uop be dispatched 
to. On Nehalem, there are six execution ports, from which port 0, 1, 5 being general-purpose ALUs, port 2 being the load 
unit, port 4 being the store unit, and port 3 being the address generation unit. An uop can be issued to one or more ports. 
Port constant definition can be found in decoder.cpp. Macro `PORT_0` to `PORT_5` defines the constant for a single port. 
`PORTS_015` is defined as the bitwise OR of `PORT_0`, `PORT_1` and `PORT_5`, which is used to indicate that the uop can 
be executed by any of the three general-purpose ALU.

zSim assumes that most function units are pipelined, which means that one uop can be dispatched each cycle regardless 
of the latency (intermediate states of the functional units are stored in the pipeline buffer of the unit). Some uops,
however, must be handled in a non-pipelined manner, which means that no uop can be dispatched to the functional unit
after the uop has been dispatched. The number of cycles of non-pipelined execution of the uop is stored in the `extraSlots`
field. When modeling instruction dispatching, no uop can be dispatched to a port within `extraSlots` future cycles if the 
most recent uop has a non-zero `extraSlots` value.

Each uop also contains a type field, which can be of value `UOP_GENERAL`, `UOP_LOAD`, `UOP_STORE`, `UOP_STORE_ADDR`, or 
`UOP_FENCE`. Among these types, `UOP_GENERAL` refers to uops that are not part of a load, a store or a fence instruction
(note that some instructions may effectively be treated as a fence). zSim does not model general uops besides their 
latencies and port masks. `UOP_LOAD` and `UOP_STORE` refer to load and store uops respectively. `UOP_STORE_ADDR` refers
to the uop that calculates store addresses. We handle this type differently to model store-load forwarding, since we
can only determine whether a load needs forwarding after all previous stores addresses are computed.

We list fields and descriptions of `struct DynUop` in the following table.

| `DynUop` Field Name | Description |
|:--------------:|------------------|
| rs | Source registers of the uop; Can be architectural or temporary registers. |
| rd | Destination registers of the uop; Can be architectural or temporary registers.  |
| lat | Number of cycles from dispatching to completion. |
| decCycle | Relative cycle (starting from zero) the uop is generated by the decoder. |
| type | Type of the uop. |
| portMask | Ports that this uop can be scheduled on. |
| extraSlots | Blocks the port on which the uop is scheduled from dispatching for this number of cycles. |
{:.mbtablestyle}

### Architectural and Temporary Registers

To model data flow dependencies between uops and between instructions, we store source and destination registers in 
`struct DynUop`. A uop cannot be issued before all its dependent source registers become available (i.e. uops
that write to them are committed). A uop updates the timestamp of these registers when it commits to "wake up"
following uops. To model dependencies between instructions, we directly use architectural registers, which are obtained 
from PIN, as source (destination) operands for uops that read the operand from a previous instruction (write the result
for a later instruction). To model dependencies between uops, we use temporary registers that may not physically exist
on a chip, but are just there to encode the dependency. In practice, these temporary "registers" may just be ROB entries.
All registers are represented using a constant register number.

Register number constants are defined in decoder.h. Register number zero represents invalid register (not defined in zSim source). 
From register number 1 to `REG_LAST` are architectural registers that might be returned by PIN. They are defined in PIN
header files. From `REG_LAST + 1` (`REG_LOAD_TEMP`) to `REG_LAST + MAX_INSTR_LOADS` are temporary values that are generated by load uops.
They are often used to model dependency of load and store uops from read-modify-write instructions. From `REG_LOAD_TEMP + MAX_INSTR_LOADS`
(`REG_STORE_TEMP`) to `REG_LOAD_TEMP + MAX_INSTR_LOADS + MAX_INSTR_STORES` are temporary values that are generated by other
instructions, and are to be written by store uops. From `REG_STORE_TEMP + MAX_INSTR_STORES` (`REG_STORE_ADDR_TEMP`) to 
`REG_STORE_TEMP + MAX_INSTR_STORES * 2` are store address temporary registers, which are used to hold addresses computed
by store address uops. From `REG_STORE_ADDR_TEMP + MAX_INSTR_STORES` (`REG_EXEC_TEMP`) to `REG_STORE_ADDR_TEMP + MAX_INSTR_STORES + 64`
are temporary values generated by other uops. They are often used as the source operands of uops from the same instruction.

zSim only models full registers. Partial registers in x86, such as 8-bit, 16-bit and 32-bit registers, will be converted 
to the full-sized 64-bit counterparts using PIN library call `REG_FullRegName()`. Modern compilers seldom generate 8-bit 
and 16-bit partial register instructions for efficiency reasons, which makes simulation error negligible.

### Pre-processed Instructions

Before an PIN instruction object (`class INS`) can be processed by the decoder, we first pre-process the `INS` object to 
extract its register and memory operands. The zSim pre-processed instruction object is defined as `class Decoder::Instr`.
Its constructor takes a PIN `INS` object as argument, and populates the register operands, register outputs, memory loads
and memoey stores. Note that an instruction may have more than two operands, and each operand can be both read and written
by the same instruction. Correspondingly, in the `Instr` representation, one operand may occur as both source and destination, or both
read and written. We list fields of `class Decoder::Instr` and their descriptions in the following table.

| `Decoder::Instr` Field Name | Description |
|:--------------:|------------------|
| ins | PIN instruction object. |
| loadOps | An array of memory read operand IDs. Used with PIN `INS_OperandMemoryBaseReg()` and `INS_OperandMemoryIndexReg()`. |
| numLoads | Number of memory read operands (i.e. the size of the `loadOps` array). |
| storeOps | An array of memory write operand IDs. Used with PIN `INS_OperandMemoryBaseReg()` and `INS_OperandMemoryIndexReg()`. |
| numStores | Number of memory write operands (i.e. the size of the `loadOps` array). |
| inRegs | An array of source register IDs, both explicit and implicit (e.g. FLAGS). |
| numInRegs | Number of source registers (i.e. the size of the `inRegs` array). |
| outRegs | An array of destination register IDs, both explicit and implicit (e.g. FLAGS). |
| numOutRegs | Number of destination registers (i.e. the size of the `numOutRegs` array). |
{:.mbtablestyle}

### Converting Instructions to Uops

As discussed in previous sections, before a basic block is instrumented by PIN, the instrumentation routine `Trace()` calls
`decodeBbl()`, defined in decoder.cpp, to statically decode the basic block. The decoded information is returned via a 
`BblInfo` object, which contains metadata of the block and timing information of decoded uops.

Function `decodeBbl()` loops through the list of instructions using PIN iterator functions. For every instruction visited,
we first check whether uop fusion is possible. Uop fusion is a technique to generate less than one uop per instruction
by leveraging common code patterns, similar to pattern-based compression algorithms. zSim only models uop fusion pattern 
consisting of a compare or test instruction followed by a jump. Extra conditions also apply, such that the compare or 
test instruction must not use immediate value as operands, and that the jump must not be an indirect jump. The function
checks whether these conditions hold by calling `canFuse()`, and if the result is positive, `decodeFusedInstrs()` is called
to emit a single uop for the fused pattern. The single uop use both RFLAGS and RIP as destination registers.

If the instruction cannot be fused with the next one, then `decodeInstr()` is called to emit uops for the current instruction.
Uops will be emitted into an array, `uopVec`. We do not cover details of uop emission, since they are mostly mechanical
and uninretesting. The rule of mapping instructions to uops can be found in [Agner's Blog](https://www.agner.org/optimize/),
[Instruction Tables (PDF)](https://www.agner.org/optimize/instruction_tables.pdf). zSim implemented a large subset of the 
x86 instruction set, but there are still unsupported instructions, such as fence instructions (`LFENCE`, `SFENCE` and 
`MFENCE`).

Besides `uopVec`, another four arrays track how instructions are broken intp uops. They are all indexed by instruction
IDs within the basic block. `instrAddr` stores addresses of instructions. `instrBytes` stores number of bytes of 
instructions. `instrUops` stores the number of uops each instruction generates. Lastly, `instrDesc` stores the `INS`
object itself. These information are later used to determine pre-decoder and decoder cycles of generated uops.

### Simulating Pre-Decoder

In Nehalem pipeline, fetched instructions are first delivered to a pre-decoder, in which instruction boundaries are drawn.
On x86 platform, this is not a trivial task, since x86 instructions are variably sized, with a maximum length of 15 bytes.
To complicate things even more, instruction prefixes can be applied to add extra features or to change the semantics such 
as operand size. zSim does not model decoding latency of prefixed instructions. Prefixes themselves, however, are still
modeled, such that a prefixed instruction may lower the decoding bandwidth by occpying more storage.

zSim models the pre-decoder using three cricial paremeters: Block size, maximum instruction per cycle, and maximum number
of pre-decoded bytes per cycle. The pre-decoder reads instruction memory in 16-byte blocks. It will not proceed to fetch
the next 16 byte before finishing all instructions in the current block. Within a block, at most 6 instructions or 16
bytes (i.e. entire block) can be processed in a cycle, whichever is reached first.

zSim also assumes that basic blocks can be decoded independent from each other. In other words, the decoder should be 
in a clean state in which there is no undecoded instructions from the previous basic block. This assumptions is generally
true, if the compiler aligns every basic block to 16-byte boundaries, since the pre-decoder will not proceed to fetch
the next block before finishing the current block. Even in the cases that this cannot be satisfied, a comment in 
decoder.c claims that the error should be small.

Current pre-decoder cycle is stored in a local variable `pcyc`, beginning from zero. `pblk` stores the relative block
number of the 16-byte block the current instruction resides in, starting from the beginning of the basic block. `pcnt`
stores the number of instructions that have been pre-decoded. `psz` stores the number of bytes that have been pre-decoded.
We iterate over all instructions in the current basic block. We scan the maximum instruction "prefix" that: (1) is 
smaller than 16 bytes; (2) contains less than six instructions; and (3) does not cross 16 byte boundary. Note that condition
(1) and (3) are not entirely identical, since the basic block may not begin at 16-byte boundary. We assign pre-decoder 
cycle to instructions by updating the array `predecCycle` using the current value of `pcyc`. If any of the above three
conditions could not hold, we increment `pcyc`, indicating that the pre-decoder must process the following instructions
in the next cycle.

### Simulating Decoder

Decoder is simulated right after we finish simulating pre-decoder. The decoder logic assumed by zSim can be summarized as 
"4-1-1-1" rule: At most four instructions can be decoded at a time using the three simple decoders and one complex decoder.
The three simple decoders can decode instructions that are less than eight bytes in size, and generate one uop at a time.
The complex decoder can decode instructions that generate up to four uops (including simple instructions), and there is 
no limit on instruction size. More complicated instructions are decoded using the micro-sequenced ROM, which is not modeled, 
since they are rarely used in practice.

The decoder stage is simulated as follows. Local variable `dcyc` tracks the current decoder cycle. For each uop generated,
we keep the `dcyc` value of an uop always no less than the pre-decoder cycle (`predecCycle`) of the corresponding instruction
by adjusting `dcyc` to `predecCycle[i]` where `i` is the index of the instruction. This indicates that the pre-decoder 
becomes the bottleneck, and the decoder is stalled for `predecCycle[i] - dcyc` cycles waiting for the pre-decoder. Variable 
`dsimple` and `dcomplex` tracks the number of simple and complex instructions. If at a given cycle, no more instruction 
can be decoded according to the "4-1-1-1" rule, we just increment current decoder cycle `dcyc` to indicate that
the next instruction can only be decoded in a different cycle than previous instructions. `dsimple` and `dcomplex` are 
incremented accordingly based on the type of the decoded instruction. We assign `dcyc` to uop's object `decCycle` field
for later use. 

Note that both `dcyc` and `pcyc` (pre-decoder cycles) are initialized to zero, meaning that we simulate basic block decoding
starting from cycle zero. These "relative" cycles will be converted to actual cycles of the processor pipeline during dynamic 
simulation of the basic block, as we will discuss below.

After decoder simulation completes, a `BblInfo` object is allocated to store static information of the basic block,
including the size, the number of instructions, and decoded uops. The `BblInfo` object contains a `DynBbl` object
at the end, which itself contains an array of `DynUop` objects. These structs are variably-sized to increase access 
locality. The `BblInfo` object will also be passed to the analysis routine before the basic block is executed.

## Simulation Overview

### Simulation Entry Point

The rest of the pipeline is simulated dynamically after execution of the basic block is completed. Simulation is performed 
in the granularity of basic blocks. Recall that zSim instrumentes all basic blocks such that the call back `OOOCore::BblFunc()` 
will be invoked before the basic block is executed. This function further calls into `OOOCore::bbl()`, the entry point of
pipeline simulation. 

At the beginning of the function, we first check whether it is the first basic block ever executed since simulation started. 
If true, then no simulation is performed, since zSim only simulates a basic block after its execution has completed. Otherwise, 
we simulate the basic block pointed to by `prevBbl`, and save the current basic block pointer in `prevBbl`. Both the previous and the 
next basic blocks are needed, since zSim simulates both the execution of the previous basic block and the fetch of the 
next basic block. Branch prediction is also simulated for the branch instruction at the end of the previous block. 

### System Parameters

zSim allows users to configure the parameter of the pipeline it simulates. Different from cache system simulation, in which
parameters are specified in the configuration file, microarchitecture simulation parameters are mostly defined as macros
to enable better compiler optimization. According to code comments, the pipeline simulation code is one of the performance
bottlenecks of zSim, the efficiency of which is critical to overall simulation performance. In the following table,
we list all configurable system parameters, with an explanation for each and their default values.

| Parameter Name | Type | Explanation | Default Value |
|:--------------:|:----:|-------------|:-------------:|
| FETCH_STAGE | Macro | Fetch stage's position in the pipeline | 1 | 
| DECODE_STAGE | Macro | Decode stage's position in the pipeline | 4 | 
| ISSUE_STAGE | Macro | Issue stage's position in the pipeline | 7 | 
| DISPATCH_STAGE | Macro | Dispatch stage's position in the pipeline | 13 | 
| L1D_LAT | Macro | l1d latency in the perspective of the pipeline | 4 | 
| FETCH_BYTES_PER_CYCLE | Macro | Number of bytes the fetch unit reads per cycle | 16 | 
| ISSUES_PER_CYCLE | Macro | Maximum number of uops that can be inserted into the instruction per cycle  | 4 | 
| RF_READS_PER_CYCLE | Macro | Maximum number of reads to RF | 3 |
| BranchPredictorPAg\<NB, HB, LB\> | Template | Branch predictor parameters (not covered) | 11, 18, 14 | 
| WindowStructure\<H, WSZ\> | Template | WSZ specified instruction window size. H is only used internally. | 1024, 36 |
| ReorderBuffer\<SZ, W\> | Template | SZ is the size of ROB; W is the maximum number of uops that can be retired per cycle. | 128, 4 for ROB<br />32, 4 for load queue<br />32, 4 for store queue |
| CycleQueue\<SZ\> | Template | Size of the issue queue | 28 |
{:.mbtablestyle}

### The Inductive Model

zSim simulates all important pipeline components for a single uop in one iteration, deriving the cycles in which the uop is 
received and released by these components. Only components that can stall the pipeline are simulated, such as the issue queue, 
the instruction window, the Register Aliasing Table (RAT) and Register File (RF), the Reorder Buffer (ROB), and the load store 
queue. Non-stalling stages, by definition, must always sustain a steady uop throughput, which means that uops always 
traverse through these stages in fixed number of cycles. Uops are fed to the pipeline in the order they are generated by 
the decoder, which is also consistent with program order. This in-order simulation technique makes sense even for out-of-order 
cores, since most components of an out-of-order core are still in-order, such as fetch, decode, issue, and retirement. Loads 
and stores are pushed into the load and store queue in program order as well.

zSim core simulation leverages two inductive rules to compute the receiving and releasing cycles of an uop for every 
simulated component. The first inductive rule states that, given a series of uops, uop<sub>1</sub> ... uop<sub>n</sub>, 
and a series of pipeline components (in the physical order), S<sub>1</sub>, ..., X, Y, ..., S<sub>m</sub>, we can compute 
the receiving and releasing cycle of any uop<sub>i</sub> on component Y, if the releasing cycles of all previous uops on 
all components are known. The second inductive rule states that, given uops and stages identical to what have been stated
above, we can compute the releasing cycle on *X* and the receiving cycle on *Y* for any uop<sub>i</sub>, if (1) the 
receiving cycle of uop<sub>i</sub> on *X*; (2) the receiving and releasing cycles of uop<sub>i</sub> on all previous 
components; and (3) the releasing cycles of all previous uops on all components, are known. 

From a high level, The first induction allows us to derive the timing of all uops in the program order. 
the second induction allows us to start from the initial component (the receiving cycle on which is 
known), deriving the receiving and releasing cycles of one single uop on all components by indictively applying 
the rule while "pushing" the uop down the pipeline. We next use an example to illustrate this process. 

Assume *X* and *Y* are two stalling pipeline components. Without loss of generality, we also assume that there are *k* 
non-stalling stages in-between. Given that we have already derived the receiving and releasing cycle of all previous uops 
in a basic block, and that the receiving cycle of the current uop by stage *X*, C<sub>X</sub>, is also known. Our goal is 
to compute the releasing cycle of the current uop at stage *X* and the receiving cycle at *Y*. Note that in our model, 
adjacent uops can be received and released by a component in the same cycle, since modern out-of-order cores 
are likely also superscalar, meaning that more than one uops are transferred from one stage to the next on the datapath 
in every cycle. To simplify discussion, we assume a datapath of width one in the following example.

There are two possibilities to consider. In the simpler case, stage Y does not buffer uops. It stalls the pipeline 
immediately if the uop cannot be processed in the current cycle. One example is register fetch, in which the pipeline
is stalled if some source registers of the uop are not yet available. Recall that we have already computed the release
cycle of the previous uop on stage Y, call it C<sub>Y</sub>. Since stage Y does not buffer uops, it can only receive
an uop after the previousu uop has been released (on actual hardware these two happens in the same cycle, though).
We compare the value of (C<sub>X</sub> + k) and C<sub>Y</sub>. If (C<sub>X</sub> + k) < C<sub>Y</sub>, meaning that if 
the uop is released at cycle C<sub>X</sub>, it will arrive at component *Y* before the previous uop has been processed,
we must stall component *X* for (C<sub>Y</sub> - k - C<sub>X</sub>) cycles to allow component *Y* sufficient time
to process the previous uop. The release cycle of the current uop on *X* is therefore (C<sub>Y</sub> - k),
and the receiving cycle on *Y* is C<sub>Y</sub>. If, on the other hand, (C<sub>X</sub> + k) > C<sub>Y</sub>, then the uop 
can be released as soon as possible, since component *Y* will be idle for (C<sub>X</sub> - C<sub>Y</sub> + k) cycles before 
the current uop arrives. The releasing cycle on *X* is therefore C<sub>X</sub> and the receiving cycle on *Y* is 
(C<sub>X</sub> + k). To summarize: we always use the larger of (C<sub>X</sub> + k) and C<sub>Y</sub> as the receiving cycle 
on component *Y*. 

In the harder case, component *Y* has an attached FIFO buffer, which can keep receiving uops until the buffer is full. 
To properly model the buffer, we no longer assume that uops can only be processed in distinct time ranges. Instead,
we take advantage of the following observation: Given a FIFO buffer of size *SZ*, the receiving time of any uop<sub>i</sub> 
must always be greater than the releasing time of the previous uop on the same slot. Since the buffer is FIFO, the previous 
uop on the same slot can be easily computed as uop<sub>i - SZ</sub>. Recall that we assume the receiving and releasing cycles 
of all previous uops on all components are known. Then this problem essentially boils down to determining the releasing
cycle on *X* and receiving cycle on *Y* given that the current uop uop<sub>i</sub> cannot be received by component *Y* 
before uop<sub>i - SZ</sub> leaves the buffer, the value of which is known. The same reasoning in the previous case
can be applied, and the conclusion is basically the same except that we maintain a separate releasing cycle for each slot 
on buffered components.

### Discrete Event Simulation

What if component *Y* has an attached buffer, which is not necessarily FIFO? This is the case for instruction
window, where uops enter in program order, but can leave in a different order determined by the uop scheduling
algorithm. The buffer is essentially fully-associative, meaning that uops can be received as long as there is a vacant 
slot. In this case, we no longer maintain separate releasing cycle for each slot, since the slot of an uop cannot be 
determined statically. Instead, we use discrete event simulation (DES) with an explicit "current clock" variable associated 
with the component. The releasing of uops can be scheduled as events in the future, the time of which is computed according
to the scheduling algorithm and availbility of issuing ports (explained later in section "Instruction Window"). The receiving 
time of an uop can be determined by checking if the window is full in the current cycle. If true, the clock is driven forward 
until a vacant slot occurs as the result of processing uop releasing events. Note that although uops leave the component 
out-of-order, in-order simulation of uops is still feasible, since at the end of the pipeline, uops must leave the ROB in 
program order.

## Simulating The Rest of Frontend

We next describe each frontend stage of the pipeline in a separate section.

### Decoder Cycle

In the dyanmic core implementation, the current decoder cycle is maintained in `OOOCore`'s member variable `decodeCycle`, 
which is updated when a new uop is simulated at the beginning of the loop by adding the difference between the current uop's 
relative decoder cycle and the previous uop's relative decoder cycle (stored in `prevDecCycle` and updated to the current
uop's relative cycle after) onto the variable. The decoder cycle represents the actual releasing cycle of the most recent 
uop generated by the decoder.

### Issue Queue

The Issue Queue is a circular FIFO uop buffer sitting between the decoder and the instruction window in Nehalem architecture
(in Core 2 it is between the pre-decoder and decoder). It serves as a temporary storage for uops from tight loops, such
that the loop body can be directly fetched from the buffer rather than from the fetch-decode frontend, reducing latency 
and energy consumption. On the other hand, zSim does not model any temporary uop cache in the pipeline, and always 
simulates uops (instructions) from the fetch stage. The issue queue modeled by zSim is simply a FIFO queue structure between 
the decode and the issue stage, on which resource hazard may happen. 

The issue queue is implemented in decoder.h as `class CycleQueue`, and defined in `class OOOCore` as `uopQueue`. The size
of the issue queue is a statically determined value implemented as a template argument. This also applies to other
queue and buffer structures such as the ROB, load store queue, and instruction window. According to code comments, this
design decision is made to avoid the extra level of indirection introduced by dynamically determined structure sizes, since 
in that case, the size of the type is unknown to the compiler, and the array could not be directly embedded in the struct.
The issue queue consists of an array of timestamps (`buf`) and a tail pointer (`idx`) indicating the receiving end of the 
queue. Timestamps in the array are releasing cycles of the most recent uops that are stored in that location. According to
the inductive model discussed in the previous section, for each uop generated by the decoder at cycle C, we compare C
with the value on the current receiving slot in the buffer pointed to by `idx`. If the value is greater than C, then we 
stall the decoder, and only release the uop from the decoder at cycle `buf[idx]`. Otherwise, we release the uop as soon
as it is generated by the decoder at cycle C.

In ooo\_core.cpp, `uopQueue.minAllocCycle()` is called to return the value of `buf[idx]`, which is the minimum receiving 
cycle of the current uop. The decoder is stalled if the current `decodeCycle` is less than the return value, in which case
we drive the decoder's local clock forward by setting `decodeCycle` to the value of `uopQueue.minAllocCycle()`. 

## Simulating The Backend Pipeline

### Backend Overview

The backend of the pipeline consists of the Register Aliasing Table (RAT), the Register File (RF), the out-of-order execution 
engine, load store unit, and the Reorder Buffer (ROB). Uops are "issued" to the backend from the issue queue at a maximum 
bandwidth of `ISSUES_PER_CYCLE` uops per cycle, meaning that each backend pipeline stage can handle that many uops in a 
single cycle. zSim keeps track of the current issue cycle in `OOOCore`'s member variable, `curCycle`, making the entire 
core simulator "issue-centric". With the inductive model in mind, `curCycle` can also be considered as the backend receiving 
cycle of the previous uop in program order. 

Uops that are issued in the same cycle form a "batch" that traverse through the backend pipeline. One interesting property
is that an uop stall at any stage of the backend pipeline can be modeled as issuing the uop and all following uops one 
cycle later. We justify this using two observations. First, the delivery of the uop to instruction window and ROB will 
be delayed for one cycle anyway at the end of the six stage backend pipeline, and this is all that we care. Second, uops 
are always issued in-order, meaning that if an uop is stalled in the middle of the pipeline, all following uops must also 
be stalled by at least the same amount of time. On real hardware, this is equivalent to inserting bubbles into the next
stage and stalling previous stages, while withholding (some of the) uops in the current stage.

Readers should be careful not to confuse uop issue with uop dispatch. In zSim, issue is a terminology that refers to moving
uops to the backend pipeline stage, while dispatch means moving the uops to the functional units through one of the six 
execution ports. An uop is first issued to the backend, renamed by the RAT, then inserted into the ROB and the 
instruction window, only after which could the uop be dispatched when all source operands are ready and an execution
port is available. Readers should also note that Intel may not use these two terminologies in the same way zSim uses them
for historical reasons. In the following discussion, we will strictly stick to zSim's interpretation of "issue" and "dispatch"
to avoid confusion. Similarly, when two terminologies refer to the same thing, we only use the one suggested by 
the code. One example is "instruction window" and "reservation station". We choose the former despite the fact that
Intel uses the latter to refer to the exact same structure.

There are three major stages in the backend, each taking at least two cycles to complete. This sums up to six cycles between
uop issue and dispatch at a minimum. As pointed out in previous paragraphs, zSim always models stall in the middle of the 
backend pipeline by delaying the issue of the current and all following uops as if the current uop magically knew a stall
will happen if it were issued without the delay. With this in mind, we can think of the backend pipeline as always taking
six cycles to complete after we adjust the issue cycle to model stalls. 

The first stage is register renaming. The RAT allows renaming four uops per cycle, regardless of whether the same register 
is renamed multiple times. Since this is consistent with the issue width, we do not need to model RAT. As a ressult, the 
renaming stage does not introduce stalls, and always completes in two cycles. The second stage is register read, in which 
the renamed source register is read. zSim models register read throughput limit, which is specified in `RF_READS_PER_CYCLE`. 
The third stage is ROB and instruction window, in which the uop is inserted into both the ROB and the instruction window. 
As discussed earlier, FIFO buffer structure can be simulated using an array of releasing cycles. The instruction window 
can be simulated using DES. In the following sections we cover the three stages in full details.

### Simulating Uop Issue

After the uop is inserted into the issue queue in `decodeCycle`, we compare `decodeCycle` and `curCycle` to determine
which component should be stalled. Recall that `curCycle` represents the issue cycle of the previous uop. If `decodeCycle`
is greater than `curCycle`, meaning the current uop is enqueued after the previous uop has been issued, we stall the 
issue logic for (`decodeCycle` - `curCycle`) cycles, and adjust `curCycle` to `decodeCycle`. Otherwise, `decodeCycle`
is smaller than or equal to `curCycle`, which means that the previous uop is only issued (`curCycle` - `decodeCycle`) 
cycles after the current uop is inserted. In this case, the current uop will stay in the issue queue for 
(`curCycle` - `decodeCycle`) cycles to wait for the issue of the previous uop first. Note that in the latter scenario,
we do not stall the decoder by adjusting `decodeCycle` to `curCycle`, since the decoder is stalled naturally by the 
return value of `minAllocCycle()` when the issue queue becomes full.

The current uop can leave the issue queue in `curCycle` if the number of already issued uops, which is stored in 
`curCycleIssuedUops`, have not reached the issue limit, `RF_READS_PER_CYCLE`. If this is the case, we increment 
`curCycleIssuedUops` by one, and record the release cycle of the uop in the issue queue by calling `markLeave()` member 
function with `curCycle` as argument. Otherwise, the current uop cannot be issued at the current cycle. In this case, we 
just let it stay in the issue queue for one more cycle, and reset `curCycleIssuedUops`.

### Simulating RAT and RF

As discussed above, the RAT has a renaming bandwidth of four uops per cycle, which matches the maximum issue width, and 
therefore does not constitute a bottleneck in any situation. The RF, on the other hand, only supports at most three reads 
in one cycle. If the uops issued in the same cycle need to access more than three registers from the RF, only the first 
few requests can be handled in the program order (i.e. requests from uops that come earlier in program order have higher 
priority), and these uops can be released to the next pipeline stage. The rest uops will be withheld in the RF read stage 
for one more cycle, in which RF read will be re-attempted. Note that zSim does not model register write backs and read-write 
contention, meaning that the RF read bandwidth does not change in the presence of concurrent write backs. 

zSim models RF read stall slightly differently than what was described above. On actual hardware, we can stall an uop
by withholding it in the current stage, stalling previous stages, and inserting bubbles into the next stage. zSim does
not model concrete pipeline states. Instead, it assumes that uops magically know, at issue time, whether their RF read
would be stalled by one cycle if it were issued in `curCycle`. If it is the case, then the uop will not be issued in
`curCycle`, essentially stalling uop issue for one cycle, instead of stalling in the middle of the backend pipeline.
This artifact, however, does not affect the timing of uops at the end of the backend pipeline, as we have arguged in 
previous sections. Note that although RF read stall is equivalent to delaying uop issue by one cycle, this is 
not reflected in the issue queue. The issue queue always stores `curCycle` before it is incremented for RF read stalls.

The core tracks the number of RF reads from uops issued at `curCycle` in member variable `curCycleRFReads`. If the aggregated
numbre of register read requests exceeds the maximum, `RF_READS_PER_CYCLE`, we stall the issue of the current and all following 
uops by one cycle by incrementing `curCycle` and deducting `RF_READS_PER_CYCLE` from `curCycleRFReads`.

### Register Scoreboard

One question is left unanswered in the previous section: How do we know the number of registers to read from RF for each 
uop? To answer this question, we must define the register renaming and propagating model. zSim assumes that only one physical
register file exists, which stores the value of architectural registers. When an uop commits, the value it computes 
(if any) is temporarily buffered in the ROB, and broadcasted to the backend pipeline. Uops in the backend pipeline 
snoop on the ROB broadcasting bus, and grab the value from the bus if it matches one of the sources operands. When an
uop retires, the temporary value in the ROB is written back to the physical RF. At any time during the execution, the 
physical RF always represents the current consistent architectural state, which simplifies exception handling and branch
misprediction. 

zSim models the above mechanism using a register scoreboard, which, for each architectural and temporary register, stores 
the most recent commit time of uops that write into the register. The register scoreboard is updated when an uop commits
using the commit cycle and two destination register IDs. Unfortunately, zSim does not model register write back on retirement.
Instead, it simply assumes that registers that are committed after the uop is issued can be read from the broadcasting
bus with zero dynamic overhead, while registers that are committed before the uop must be read from the physical RF.

Note that in the code comment right above RF read simulation, it is said that 
`// if srcs are not available at issue time, we have to go thru the RF`. This is incorrect. The author even confused himself
with the ROB-based renaming model. In fact, if sources are not available at issue time, the uops can snoop them on
the broadcasting bus, eliminating the RF read. The code below also contradicts the comment: 
`curCycleRFReads += ((c0 < curCycle)? 1 : 0) + ((c1 < curCycle)? 1 : 0);`. RF reads are requested only when the results
are already available before instruction issue.

Another purpose of the scoreboard is to ensure that an uop can only be dispatched after all its source operands are 
computed by previous uops in the program order. Local variable `cOps` stores the minimum cycle the uop can be dispatched.

### Reorder Buffer (ROB)

The ROB, just like issue queue, is also modeled as a FIFO circular buffer. The implementation of the ROB can be found
in ooo\_core.h, `class ReorderBuffer`. One important difference between the ROB and issue queue is that uops may commit 
out-of-order, but they always leave the ROB in-order. Besides, more than one uops can leave the ROB in one cycle. This is 
defined as the ROB's width, specified using template argument `W`.

The ROB class maintains two more member variables than the issue queue: `curRetireCycle` and `curCycleRetires`. 
`curRetireCycle` tracks the maximum retire cycle of all previous uops. Recall that uops are always simulated in-order,
previous uops' retire cycle is always known. `curCycleRetires` tracks the number of entries we have retired in the 
current retire cycle. If this number reaches the ROB width, we simply increment `curRetireCycle` and resets `curCycleRetires`.

The ROB maintains the invariant that the current uop must not retire earlier than previous uops. Retirement is handled by
member function `markRetire`, with argument `minRetireCycle`, which is, in fact, the commit cycle of the uop. We compare
`minRetireCycle` with `curRetireCycle`. If the latter is smaller, the current uop is committed earlier than previous uops,
and it has to wait in the ROB for (`curRetireCycle` - `minRetireCycle`) cycles before retirement. If, on the other hand,
the latter is larger, we know the ROB remains idle for (`minRetireCycle` - `curRetireCycle`) cycles after retiring the 
previous uops, in which case we simply adjusting `curRetireCycle` to `minRetireCycle` and reset `curCycleRetires`.

Taking the retirement bandwidth limit into consideration, when a uop commits at cycle `minRetireCycle` but the previous
uops retire in a larger cycle `curRetireCycle`, we should check whether the number of instructions that are already 
retired before the current uop in `curRetireCycle` equals `W`. If true, the uop must stay in the ROB for one more 
cycle, since the previous `W` uops have already exhausted the retirement bandwidth. We model this by incrementing
`curRetireCycle` and resetting `curCycleRetires`.

After retiring the current uop, we store the actual retirement cycle `curRetireCycle` into `buf[idx]`, and increment
`idx`. Resource hazard on the ROB will stall uop issue if an uop is to be inserted into an ROB slot, but
the retirement cycle stored in that slot is larger than the issue cycle. In this case we model the stall by adjusting
`curCycle` to `buf[idx]`, the return value of ROB's `minAllocCycle()`. The core implementation, however, somehow does not 
include this. It looks as if resource hazard on ROB never stalls uop issue.

### Instruction Window

The instruction window implements a simple DES event queue as `class WindowStructure` (ooo\_core.h). In order to model 
out-of-order uop dispatching, we compute, for each uop received, the nearest cycle in the future that the uop can be 
dispatched, and schedule a dispatch event in the future dispatch cycle. The state of the instruction window at any point
during the simulation is on the cycle when the current uop arrives at the window. In other words, for an uop issued at
`curCycle` (after adjustment for backend pipeline stalls), the state of the window is the state at (`curCycle` + 6).

The instruction window maintains one of the most important invariants in zSim: When `curCycle` is adjusted for modeling
backend pipeline stalls and external stalls, we should always call `advansePos()` to synchronously update 
the state of the window by one cycle (`longAdvance()` updates window state by a potentially large number of cycles, but this 
function seems unused, as I did a `grep -r longAdvance` and found no usage of it). This invariant must be solidly observed
even when the instruction window itself stalls the pipeline due to a resource hazard. 

At a high level, the instruction window maps future cycles to event objects implemented as `struct WinCycle`. These 
event objects track which ports are in-use at the event cycle. Port can become in-use for a given cycle 
either because an uop is scheduled on that port during the cycle, or because the functional unit is non-pipelined and a 
uop using the function unit was scheduled a few cycles before (recall `extraSlots` in `DynUop`), or because the load store 
queue imposes back pressure to block instruction issue. If a port is already in-use, no uop can be scheduled on that port
during the event cycle. 

At a closer look, the `struct WinCycle` event object consists of an 8-byte port mask and a uop counter. The port mask 
field `occUnits` tracks which ports are already in-use. The uop counter `count` tracks the number of uops scheduled in 
the corresponding cycle. Note that although the code comment mentions using "POPCNT", which is a x86 instruction for 
counting "1" bits, to replace `count` field, this is incorrect, since the value of `count` may not equal the POPCNT 
of `occUnits`. This happens when the port is closed due to a non-pipelined functioal unit or when the load store queue 
imposes back pressure.

The member variable `occupancy` tracks the size of the structure when the current uop issued at `curCycle` (after adjustment)
arrives at the window, which equals the sum of `count` in all event objects scheduled before the current uop. When an event 
object is processed as we drive forward `curCycle`, the value of `count` is deducted from `occupancy` to simulate uop 
dispatching after which the window slots occupied by dispatched uops become free. When the uop issued at `currCycle`
is received by the window, we look into future event objects, and schedule the uop for dispatching greedily in the nearest 
cycle in which one of the required ports of the uop is not in-use. This is equivalent to buffering the uop in the window 
from the cycle of receival until the dispatch cycle. The variable `occupancy` is also incremented after scheduling an uop 
to simulate the fact that one slot is occupied by the uop.

The actual implementation of the event queue is overly complicated due to the optimizations that are applied
for better time complexity and data locality. Instead of using a single `std::map` for mapping cycles to `struct WinCycle` 
objects, two extra arrays, `curWin` and `nextWin`, are added to "buffer" cycles in the near future. This way, instruction 
window access is a constant time array indexing operation, instead of log(N) as in `std::map`. The size of the two windows
are specified by the template argument `H`. `curWin` is indexed by `curPos`, which points to the `struct WinCycle` object
representing port state in `curCycle`. The value of `curPos` is also incremented by the same amount every time we drive 
forward `curCycle`. When `curPos` reaches the end of `curWin`, we swap `curWin` and `nextWin` and reset `curPos`. The 
`nextWin` after switch (i.e. the old `curWin`) is then refilled by moving the next `H` cycles' event objects from `ubWin` 
(stands for "unbounded window"). This window-filling logic is implemented in member function `advancePos()`.

At the end of the backend pipeline, the uop is inserted into the instruction window by calling `schedule()`. This function
takes two arguments. The first is `curCycle` reference, the second is the minimum dispatch cycle computed using source
operand commit cycle, the ROB allocation cycle, and the uop issue cycle `curCycle` (to be honest, I do not quite understand 
why ROB allocation does not stall the pipeline on resource hazard, and why ROB allocation seems to happen at the beginning
of issue stage). The uop must not be dispatched before: (1) Its two source operands become available at cycle `cOps`;
(2) ROB entry is allocated at the beginning of issue stage (`c2`); (3) The uop physically arrives at the instruction window 
after issue, at cycle `MAX(c2, c3) + (DISPATCH_STAGE - ISSUE_STAGE)` (the `MAX` here seems to imply that ROB allocation 
stalls uop issue for (`c2` - `c3`) cycles, if `c2 > c3`, but `curCycle` is not incremented to account for the issue stall).

On invocation, `schedule()`'s helper function `scheduleInternal()` first checks whether the window is currently full. 
If true, the pipeline will be stalled by at least one extra cycle due to resource hazard. This is where `advancePos()` 
is called within `scheduleInternal()`. Note that `scheduleInternal()` uses a loop to simulate pipeline stall, implying that 
the stall may take more than one cycle. This can happen if no uop is scheduled for dispatching in the next cycle due
to ports being closed not for uop dispatching. After inserting the uop into the window, we traverse through future
event objects after `schedCycle` to find a cycle in which one of the required ports are available for dispatching. The 
`schedCycle` in the caller is updated accordingly when the function returns.

The scheduling logic `scheduleInternal()` is also overly complicated by the use of the two boolean template arguments, 
`touchOccupancy` and `recordPort`. In fact, what this function does is simpler than it seems to be. When a uop
is scheduled on a pipelined functional unit, `scheduleInternal()` is called with `touchOccupancy` being `true` and 
`recordPort` being `false`, indicating that `occupancy` will be incremented by one as the result of uop issue, and that 
we do not care which port it is issued into. When we want to close the port, however, no actual uop is inserted
into the window. Instead, we simply mark the port as in-use in the specified cycle to prevent later uops from
being dispatched on the port. In this case both `touchOccupancy` and `recordPort` are `false` (see `poisonRange()`
and the outermost `else` branch of `schedule()`). In the last case, an uop requiring non-pipelined functional units is 
scheduled. We need to remember the port it is scheduled on and close the port for `extraSlots` cycles by setting both 
`touchOccupancy` and `recordPort` to `true`. This indicates that `occupancy` will be incremented, and that the member 
variable of the instruction window, `lastPort`, will also be updated to remember the port on which the uop is scheduled.

### Simulating Uop Execution

After dispatching, uops are executed by functional units. zSim assumes that the execution latency of an uop is always fixed 
and can be determined statically, except for loads and stores. The commit cycle for these uops is simply dispatch cycle 
plus the execution latency stored in `lat` field of the `DynUop` object. zSim assumes that most functional units are 
pipelined, such that even if execution of uops can take multiple cycles, the functional unit can take one input uop
per cycle. Some special uops, however, must be executed by non-pipelined functional units such as the divider or some
SIMD units. In this case, the port will be closed for `extraSlots` cycles, meaning that no uop can ever be dispatched
to the port within `extraSlots` cycles after the last dispatch. This feature is implemented by instruction window's 
`schedule()`, which has been discussed above.

Store addresses are computed by the Address Generation Unit (AGU) located at port 3. One special property of store address
uop is that all loads and stores serialize on the most recent store address uop. Loads need the addresses of all previous
stores, since without store address we cannot decide whether load data can be forwarded from a previous store. Stores 
serialize on previous stores since x86 does not allow store-store reordering. The commit of store address uops is 
tracked by `OOOCore`'s member variable `lastStoreAddrCommitCycle`. It is updated to the commit cycle of the store uop
if the commit cycle is larger than `lastStoreAddrCommitCycle`. Store address cycle is used to implement full fence, 
which stalls all loads and stores from being executed until the fence uop commits.

### Simulating Load and Store

Loads and stores also allocate an entry in the load queue or store queue respectively. Surprisingly, zSim models load
and store queue exactly as an ROB with smaller capacity and a potentially different retirement bandwidth. Code comment
points out that, in practice, load and store queues are often fully associative. In our case, we only simulate them as FIFO
buffer on which resource hazards may happen. After a load or store uop is dispatched, they first call `minAllocCycle()`
on the load or store queue object respectively to obtain the minimum enqueue cycle. If this value is larger than the 
dispatch cycle, we stall the functional unit by calling `poisonRange()`, imposing back pressure to the instruction window.
The window will then close the port to prevent following uops from being issued until the current uop can be inserted
into the load or store queue. Uops are removed from the load or store queue when they commit. For store instructions, 
they might be moved to a store buffer to overlap coherence actions with execution. This, unfortunately, is not modeled
by zSim. We next describe how loads and stores are executed in details.

For store uops, after they are inserted into the store queue, we serialize the uop with all previous store addresses.
This is done by taking the maximum of the dispatch cycle and `lastStoreAddrCommitCycle`. Note that the dependency between
the current store address and the store uop is already modeled by register dependency. Here we also model the implicit
dependency between the current store uop and all previous store address computation uops using `lastStoreAddrCommitCycle`,
since store address uops may commit out-of-order. Next, we take the virtual address of the store from `OOOCore`'s member 
variable `storeAddrs`, which is populated by load and store instrumentations as the basic block is executed on native 
hardware. We then derive the store completion cycle by calling into the cache hierarchy using `l1d->store()`. The return 
value `reqSatisfiedCycle` is the commit cycle of the store uop. 

On certain conditions, the store uop may forward its data to a later load uop. zSim models forwarding using a forward
array `fwdArray`, which is a direct mapped structure mapping 4-byte aligned store addresses to the commit cycle.
When a store uop commits, we also update the forward array by setting the corresponding entry to the commit cycle
and the address of the store. 

When a store commits, `OOOCore`'s member variable `lastStoreCommitCycle` is also updated to reflect the maximum commit cycle
of all committed store uops. As we will see later, fence uops use this variable to compute the commit cycle of the fence
instruction to prevent load and store reordering of any kind.

Load uops are processed similarly. We first allocate a load queue entry, possibly stalling uop dispatch on the load port.
We then serialize the load uop with `lastStoreAddrCommitCycle` by adjusting the dispatch cycle to the larger of these two.
Note that by serializing load uop with `lastStoreAddrCommitCycle`, we are essentially stalling the load unit. This,
however, is not simulated by zSim, since the instruction window can still schedule load uops even when the load unit
is stalled waiting for the store address. After all store addresses are resolved, we take the virtual address of the load
from `loadAddrs` , and calls `l1d->load()` to simulate the cache hierarchy. In the meantime, we also test the `fwdArray`
using the load address to see if a previous store can forward its data to the current load uop. The load commit 
cycle is the larger one between cache read cycle and forwarding cycle (since the store may from long time ago).

### Simulating Fence Uops

zSim only supports very simple fence uop that stalls all loads and stores after the fence until it commits. Such fence
uop will be issued when special instructions, such as `CPUID`, or special prefixes, such as `LOCK`, are decoded. The 
fence uop serializes all memory uops after it by setting `lastStoreAddrCommitCycle`, on which both load and store 
serialize, to after its own commit cycle. This way, loads and stores after the fence (uops are simulated in-order)
can only be executed after the fence commits. 

## Simulating The Frontend Fetcher

The last instruction of a basic block is a branch instruction to the next basic block. After all uops in the current 
basic block are simulated, we proceed to simulate branch prediction and instruction fetch of the next basic block.

### Simulating Wrong Path Fetching

The branch predictor (`class BranchPredictorPAg`, ooo\_core.h) works in a straightforward way which does not require much 
explanation (and we do not cover details here). The branch predictor exposes only one method, `predict()`, which takes the 
address of the branch instruction, and the actual outcome of the branch. The return value indicates whether a misprediction 
happens. Note that zSim assumes the predictor updates its internal state right after the prediction is made. On actual
hardware this is impossible, since the branch outcome is only known after the brach instruction commits. Since zSim does 
not model the case where predictions overlap, this is a good approximation and does not introduce too much inaccuracy.

If the branch predictor indicates a misprediction, we simulate wrong path fetching by issuing instruction fetch requests
to the L1 instruction cache until the branch is resolved at commit time. To achieve this, we first compute the fetch cycle 
of the branch instruction, during which the prediction is made. Recall that all uops have been simulated at this moment, 
the fetch cycle of the last instruction is therefore fetched at cycle `decodeCycle - (DECODE_STAGE - FETCH_STAGE)`, since 
`decodeCycle` stores the dynamic cycle of the last uop generation. The wrong path fetching begins at the fetch cycle of 
the branch instruction. The simulator then computes the fetch latency of accessing L1 instruction cache using `l1i->load()`. 
The latency is added onto the fetch cycle to derive the fetch response cycle. If the response cycle is greater than 
`lastCommitCycle`, which, in our case, is the commit cycle of the branch instruction, we stop fetching from L1 instruction
cache, since the misprediction has already been identified, and the fetcher can simply abort the fetch request. Otherwise,
we keep sending request to the L1 instruction cache `lineSize / FETCH_BYTES_PER_CYCLE` cycles later. This delay is
to model the frontend fetcher's bandwidth limit, which is often smaller than cache line size (16 bytes on Nehalem). 
It is also noted by code comment that at most five blocks are fetched from the wrong path. This number is merely
from experience on average misprediction penalty. At the end of the simulation, `fetchCycle` is updated to the 
commit cycle of the branch uop, since wrong path fetching only stops when the branch uop commits.

Note that wrong path fetching does not change the timing of any uops in the current basic block. The author claimed in
code comment that wrong path fetching mainly models the contention on the cache hierarchy, such as cache misses due to
unnecessary code fetch. zSim also does not model the branch target buffer (BTB) which predicts the branch path PC.
It is assumed that if branch outcome is correctly predicted, the next basic block can be fetched immediately after that.

### Simulating Next Block Fetching

zSim simulates the fetching of the next basic block at the end of the current basic block by injecting load requests
into L1 instruction cache at current issue cycle (this is an artifact caused by weave phase model), and adding the latencies
onto `decodeCycle`, such that the simulation of the next basic block appears to start only after the entire block is fetched.
This somehow deviates from actual hardware, in which the frontend fetcher and the backend pipeline work in parallel,
and the pipeline will not wait for the entire basic block to be fetched before it resumes execution. zSim justifies
this design choice by assuming that the frontend pipeline could not hide the potentially large latency to fetch instructions.
Whenever the fetcher retrieves a block from the cache hierarchy, the pipeline will be stalled waiting for the fetch to 
complete.

The instruction fetch is simulated by calling `l1i->load()` with cache block addresses in the next basic block 
starting from `bblAddr`. The latency of the memory read is added onto `fetchCycle`. After all fetches complete, 
we compute the decoder cycle of the first instruction in the next basic block as `fetchCycle + (DECODE_STAGE - FETCH_STAGE)`,
implying that decoding stage remains idle until all instructions are fetched. To this end, we drive the decoder clock 
forward by setting it to `minFetchDecCycle`, if the latter is larger.

## Simpler Core Models

Besides Nehalem style out-of-order core, zSim offers three other core models with different complexity and timing property
for users to choose from. In the following table, we list core types and source files with a short description of their 
timing property. We then cover each type with a subsection briefly.

| Core Type | Source File (Header) | Description |
|:---------:|:--------------------:|-------------|
| `NullCore` | null\_core.h | IPC = 1 core for all instructions, including memory instruction. No memory system simulation. No weave phase timing model. |
| `SimpleCore` | simple\_core.h | IPC = 1 core for all instructions except memory instructions. Memory instructions have variable timing based on memory system simulation. Instructions are executed in-order and synchronously. Long instructions will block later instruction until it is completed. |
| `TimingCore` | timing\_core.h | Same as SimpleCore, except that time records are added during cache access to simulate cache contention in the weave phase. |
| `OOOCore` | ooo\_core.h | Out-of-order pipeline with timing record added for cache accesses. |
{:.mbtablestyle}

### NullCore and SimpleCore

The `NullCore` class is defined in null\_core.h/cpp. It is a simple IPC = 1 core which basically counts the number of instructions
executed, and no more. No extra timing model, such as cache timing and contention modeling, is implemented for this type.

The `SimpleCore` class is defined in simple\_core.h/cpp. It is an IPC = 1 core with memory system simulation. Memory instructions
(no uop is used) are simulated using the call back `LoadFunc()` and `StoreFunc()` as the instrumented basic block is executed.
It is assumed that instructions are executed serially, and only one instruction can be active at one time. Long memory
instructions will block later instructions until the long instruction complete. Instruction fetch is also simulated before
the basic block is executed. Cache line addresses of the basic block are injected into L1i cache serially, and the 
varibale `curCycle` is updated to the completion cycle of the last instruction fetch.

### TimingCore

The `TimingCore` class is defined in timing\_core.h/cpp. It is a compromise between the most complicated out-of-order
core with full contention simulation and a simple core with no contention simulation. The timing core still follows the
IPC = 1 model of `SimpleCore`, assuming that instructions are executed serially, one at a time. The difference
between these two is that `TimingCore` will generate timing records and events while the cache is accessed during the 
bound phase. When the weave phase starts, these cache access events are simulated and scheduled to model resource
hazard on MSHR and cache tag array. If an event is scheduled at time `t` in contention-free execution, but previous 
operations are delayed by `x` cycles because of contention, then the event can only be scheduled in at least cycle `t + x`.
Furthermore, if multiple tag access events are scheduled on the same cache at cycle `t`, only one of them should be 
granted, and the others must be scheduled at least one cycle later. After weave phase ends, the extra number of cycles
are added onto the process's clock (and several other clocks) to model the fact that the process has to spend more time
than expected due to contention from other cores. A similar process also exists in `OOOCore`, in which the `advance()`
method of the instruction window object is called to drain instructions for adjusting the cycle. 

The above paragraph is only a minimum description of how bound and weave phase work together to properly model contention
and to control "slacks" (difference between simulated clocks) between simulated cores. The weave phase timing model is far 
more complicated than it seems to be. I might also add a new article on zSim timing model to this series, in order to further 
explain the mechanics of discrete event simulation based weave phase.