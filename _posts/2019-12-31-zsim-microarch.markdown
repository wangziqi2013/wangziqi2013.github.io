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
is (Agner's Blog)[https://www.agner.org/optimize/], in which the structure of the pipeline and micro-op (uop) maps are described
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
and uninretesting. The rule of mapping instructions to uops can be found in (Agner's Blog)[https://www.agner.org/optimize/],
(Instruction Tables (PDF))[https://www.agner.org/optimize/instruction_tables.pdf]. zSim implemented a large subset of the 
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

## Simulating the Rest of the Pipeline

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

### Simulation Technique Overview

zSim simulates all important pipeline components for a single uop in one iteration, deriving the cycles in which the uop is 
processed by these components. Uops are fed to the pipeline in the order they are generated by the decoder, which is also 
consistent with program order. Each simulated component maintains its own clock, which represents the last time an uop is 
processed by the component. This in-order simulation technique makes sense even for out-of-order cores, since most components 
of an out-of-order core are still in-order, such as fetch, decode, issue, and retirement. Loads and stores are pushed into 
the load and store queue in program order as well. For out-of-order components, such as instruction dispatch logic, 
maintaining a single clock is insufficient, since an instruction "from the past" (with regard to the clock) may emerge, but
past states have already been "forgotten" by the component after the clock is driven forward. To solve this problem,
we maintain multiple clocks and the corresponding states (e.g. execution port occupation mask) to allow dispatching 
instructions into the future without driving forward the clock. In this case, the clock is updated conservatively
and lazily when no instruction from the past can ever arrive.

Generally speaking, this simulation technique is faster than tick-by-tick simulation of all components, since a component can 
"skip" idle cycles if a prior pipeline stage is stalled, for example, by resource hazards. In this case, zSim core model 
will simply drive forward the clock of the current component to the future cycle in which the next uop is processed by the 
prior component. This is equivalent to stalling the current component until pipelined execution resumes, except that these 
idle cycles are never simulated.

The simulation maintains two invariants. The first invariant is that the processing time of the same uop must be monotonically
increasing through the pipeline. In other words, if an uop is processed by pipeline stage A at cycle x, and pipeline stage 
B at cycle y, then as long as A is an earlier stage than B, x must be strictly less than y. This translates to the coding 
pattern that if the uop is simulated by component A at local clock x, and the current clock of component B is y, then we 
first drive the clock of component B forward by taking the maximum between x and y, and assign it to y. This way, we guarantee 
that all components' local clocks are synchronized. 

The second invariant is that for a FIFO circular buffer of size SZ and a series of elements x<sub>1</sub>, x<sub>2</sub>, 
x<sub>3</sub>, ..., x<sub>n</sub>, n >> SZ, for any arbitrary element x<sub>i</sub>, the enqueue time of xi must be larger 
than the dequeue time of the previous element at the same slot, x<sub>i - SZ</sub>. Note that the FIFO property itself 
suggests that for any element x<sub>i</sub>, the dequeue time of x<sub>i</sub> must be larger than the dequeue time its 
previous element, x<sub>i - 1</sub>. Furthermore, when the queue is mostly full, an element x<sub>i</sub> will be enqueued 
as soon as the previous element in the slot x<sub>i - SZ</sub> is dequeued. In this case, the lower bound of x<sub>i</sub>'s 
enqueue time becomes a strict lower bound, meaning that we can compute exact enqueue time by keeping track of the most recent 
leave time for all slots. In the following discussion, we will see that this invariant is applied to all FIFO buffer structures,
such as uop buffer, ROB, and load store queue.


We next describe each stage of the pipeline in a separate section.