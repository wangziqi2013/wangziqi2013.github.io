---
layout: paper-summary
title:  "Delegated Persist Ordering"
date:   2019-01-19 04:33:00 -0500
categories: paper
paper_title: "Delegated Persist Ordering"
paper_link: https://ieeexplore.ieee.org/document/7783761
paper_keyword: Undo Logging; Persistence Ordering; NVM
paper_year: MICRO 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Delegated Persiste Ordering, a machanism for enforcing persistent write ordering on platforms
that support NVM. Persistence ordering is crucial to NVM recovery applications, because it controls the order that dirty
data is written back from volatile storage (e.g. on-chip SRAM, DRAM buffer, etc.) to NVM. For example, in undo logging, two
classes of write ordering must be enforced: First, the log entry must be persisted onto NVM before dirty items does, because
otherwise, if a crash happens after a dirty item is written back and before its corresponding undo log entry, there is no
way to recover from such failure. Second, all dirty items must be persisted before the commit record is written on the NVM
log. If not, the system cannot guarantee the persistence of committed transactions, since unflushed dirty items will be 
lost on a failure. 

Without significant hardware modification, in order to enforce persistence ordering on current platforms, programmers must 
issue a special instruction sequence which flushes the dirty cache line manually first, and then instruct the memory controller
to persist these writes. The instruction sequence, called a "sync barrier", is in the form of the following: 
clwb; sfence; pcommit; sfence;. The clwb instruction flushes back cache lines without giving up permissions for read. The 
line still remains in the cache in a non-dirty state after the instruction. The two sfences around pcommit prevents store 
operations from reordering with pcommit, which itself provides no guarantee of any ordering. The implication is that a 
persistence fence is also a store fence, since it blocks later store instructions from committing (i.e. being globally 
visible) until previous stores are persisted. The pcommit instruction tells the persistent memory controller to flush its 
memory queue such that all in-flight requests will become persistent before this instruction could retire. Note that 
recently, Intel announced that the pcommit instruction has been deprecated, because memory controllers are now considered 
as part of the persistence domain: On power failure, the memory controller is guaranteed to have enough power to drain 
its write queue before the system finally shuts down. With this convenience at hand, the pcommit instruction is no longer 
required for the persistence barrier, which now only requires a few clwb instructions and an sfence at the end.

Ideally, the persistence order would be identical to the memory consistency order (i.e. the order that memory operations 
become visible to other processors), such that programmers do not have to learn another set of reasoning rules for persistence 
order. This order is called Strict Persistency. In practice, enforcing this property using sync barriers (called "Strict 
Ordering", SO) introduces non-negligible overhead on several aspects. First, SO is overly restrictive, being that it also forces 
the processor to wait for the completion of persistence operations using pcommit (or clwb), which is not required in 
strict persistency. This is because currently the NVM controller write queue does not know the ordering requirement from
the processor, and hence may schedule operations in the write queue arbitrarily for better performance (e.g. taking advantage 
of inter-bank parallelism). Second, the pcommit instruction unconditionally stalls the processor until the NVM write queue 
is drained. If other applications in the system also writes to the NVM, pcommit has no way to know which operations belong
to which process or thread, and must wait for all of them. This is unnecessary if different applications run
different tasks in the same system. Finally, the clwb instruction is expensive. Dirty cache lines with exclusive permissions
will transit to shared state after the write back. On the next write operation to the same cache line, a coherence bus 
transaction must be performed to regain the exclusive permission, which introduces some extra latency on the critical path.
Besides, the clwb instruction itself may snoop dirty cache lines of the same address on other private and shared caches, 
including the remote ones. This is because the semantics of clwb requires that if a dirty cache line exists, it must be 
written back system-wide, i.e. no cache in the system may contain a dirty line on the address after the instruction. 
This is almost the worst-case scenario of a cache coherence transaction, since the write back coherence message must
propagate to all caches in the system. (ADDED: According to Intel documentation, clwb within a TSX transaction may also
force the current transaction to abort, if any).

This paper addresses the inefficiency problem in SO from two perspectives. First, although it is beneficial to keep the 
persistence order of memory operations the same as the consistency order, the actual completion of these operations do not 
need to be kept synchronized with regular execution of the processor. By decoupling NVM operation ordering from operation
completion, the processor is allowed to overlap its execution with NVM write operations, which keeps the processor busy as 
much as possible. The second perspective is about usability: Programmers no longer need to write explicit sync barriers 
on certain points to enforce the ordering. Instead, hardware can detect and infer the ordering of memory instructions,
and automatically apply these orderings to NVM operations as well. To simplify the hardware design, only certain memory 
ordering events are tracked. The paper uses ARM architecture as the demonstrating example to show how memory consistency 
orderding can be translated into persistency ordering. There are two types of consistency ordering that we are particularly
interested in. The first is coherence ordering, which is established by coherence events between processors on the same 
memory address. The coherence ordering specifies that, if two processors contend on the same cache line, then the ordering
of the two instructions is defined as the ordering that their corresponding processors obtain ownership of the cache line.
The second is fence ordering, which is established by one processor executing a fence instruction, effectively dividing 
instructions before and after the fence into two adjacent epoches, and then the second processor establishes a coherence 
dependency with instructions on the later epoch. In this case, all instructions before the fence are ordered before instructions 
after the fence on the first processor. Furthermore, since consistency relations are transitive, instructions on the second 
processor then also implicitly establishes a consistency order with instructions in the earlier epoch. 

Based on the above observations, the paper proposes adding a special buffer called the "persist buffer", serving the purpose 
of a dedicated persistence store queue on each logic processor. The existing NVM write queue is also extended with extra 
capability of recognizing instruction barriers across which no store operation can be scheduled. We describe the details 
of the design below.

The persist buffer consists fields that help a processor determine the relative order of local stores. Each entry in the 
buffer can either be a store operation with data, or a fence instruction indicating the local and potentially global
ordering between instructions. The persist buffer flushes instructions to the NVM controller store queue whenever it 
is able to do so. The NVM controller store queue operates as follows: It accepts either an operation, or a fence instruction.
Both will be buffered in the store queue in the order that they arrive. The NVM controller is allowed to schedule NVM writes
only within fences, but not cross them. Fence instructions have no effect on the NVM content, and will be discarded if they
are at the head of the NVM store queue. 

This paper assumes a snoopy cache coherence protocol, in which write back operations can be snooped by all processors.
On every store operation to NVM address space, the instruction is enqueued at the tail of the persistence queue, while 
also being performed on the cache line. w.l.o.g. we assume that the instruction hits L1 cache, and hence requires no 
coherence action. Each entry in the buffer has the following fields: A type field indicating whether the entry represents 
an instruction or a barrier; A data field, which stores the updated data for a store operation, or a pointer to a hardware 
bloom filter, the usage of which will be explained later. There is a "Youngest" field which indicates whether the current 
entry contains the most up-to-date data for the cache line. Note that if multiple processors write to the same cache line, 
multiple instances of the entry may present in their persist buffers, and only one of them may have the "Youngest" bits set. 
The persist buffer should also snoop for coherence requests, and entries with the "Youngest" bit set should response to 
coherence requests on the dirty line, in case that the line has been evicted from the cache hierarchy. Each entry also has 
an ID field, which consists of the processor ID and an unique identifier of the entry (generated by an on-chip counter).
The ID field is included in the write back message such that other processors could see which entries have finished writing 
back. In order to track dependence introduced by coherence actions or barriers, each entry also has a "dependency" field,
which stores the ID of a remote entry that it is dependent on. The entry with a non-empty "dependency" field must snoop
on the bus and wait for the entry with the ID to be written back, before the current entry can be written back. In the 
next paragraph we describe how persistence ordering can be tracked and enforced using the persist buffer and coherence protocol.

There are two types of ordering the persist buffer must track: coherence ordering and barrier ordering. In order to track 
coherence ordering, the hardware piggybacks the ID of an entry if the entry serves a coherence request (i.e. an incoming 
request for ownership hits an entry in the persist buffer). On receiving the response containing the entry ID, the 
processor adds an entry into its own persist buffer, and fill the "dependency" field with the field ID (if the instruction
is a store to the NVM address space). The entry in the latter processor cannot be sent to the NVM controller before it
sees the entry with the ID in its "dependency" field being written back. 

The second type of ordering is introduced by executing a memory fence on one processor, and observing the effect of a 
later instruction via cache coherence on another processor. Note that the later instruction can be an instruction to
either NVM address space or DRAM address space. To precisely reflect such ordering requirements, after a fence instruction is 
executed and added to the persist buffer, the processor allocates a bloom filter to the memory fence entry in the 
buffer (and link them together using the "data" field in the entry). All memory accesses after the barrier are hashed 
into the bloom filter using their addresses. On receiving a coherence request, the persist buffer checks the requested 
address with all fences in the buffer. If one of them has a hit (if multiple hits are present, use the latest one),
the ID of the entry is piggybacked in the coherence response to indicate that the receiving processor may potentially
has a dependency with a memory operation after the fence, and hence should wait until the fence is drained. Note that
even if false positives are possible with a bloom filter, correctness is not affected, since in the case of false 
positives we only create more false dependencies.

On the receiving end of the coherence message, it is important to note that when a coherence message with piggybacked 
entry ID is received, it is not always a persist memory operation. For example, processor 1 executes a store operation
on DRAM address space after the barrier, and then processor 2 reads the same cache line. According to the transitivity
of memory ordering, the read operation should be ordered after the barrier. It is, however, impossible to add the dependency
into the persist buffer since processor 2 only executes a regular load instruction. If, later on, processor 2 stores the 
result of the load to an NVM address, the store should be persisted after the barrier, since the NVM store must be ordered
after the regular load (core-local data dependency) and the regular load is ordered after the barrier. To avoid missing
dependencies, each processor also has a register called "AccumDP", which stored dependency information carried by
coherence responses. Every time a coherence message is received, and if there is an entry ID indicating a potential
dependency, the ID will be appended into the AccumDP register. Next time an entry is allocated in the persist buffer, the 
content of AccumDP will be copied into the "dependency" field, and the register is cleared.