---
layout: paper-summary
title:  "InvisiFence: Performance-Transparent Memory Ordering in Conventional Multiprocessors"
date:   2020-12-20 23:17:00 -0500
categories: paper
paper_title: "InvisiFence: Performance-Transparent Memory Ordering in Conventional Multiprocessors"
paper_link: https://dl.acm.org/doi/10.1145/1555754.1555785
paper_keyword: Microarchitecture; Store Buffer; Memory Consistency
paper_year: ISCA 2009
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Using a speculation mechanism that is very similar to Intel RTM for enforcing memory ordering. Broadly speaking,
   transactional memory and memory consistency model often rely on the same abstraction, that is, committing a 
   multi-loand and multi-store chunk as an atomic unit.

2. From another perspective, HTM-like speculation just amortizes the cost of sequentially execution all memory
   accessing instruction by grouping them into chunks, and then sequentially execute each chunk. Note that in all
   such designs, the chunks must take effect just like memory operations in an SC model.

3. The paper also proposes a policy, besides the continuous speculation one, where the processor only starts speculation
   when local violation of the ordering is about to occur. The goal of the speculation is to commit the involved 
   instruction as an atomic unit, such that external viewers cannot infer the order of these instructions by 
   observing the intermediate state.

**Lowlight:**

1. If a speculation aborts on receiving a request, and the requested block is invalidated, then in fact L1 cannot
   handle the request by its own, since it no longer has the block. In this case, L1 should perform another bus
   transaction to L2 or lower level caches (hopefully they are inclusive, which bounds the time of this request)
   to fetch the old image first, before handling the request.

2. I think the store buffer should also be checked against external requests for violation detection (although
   I am not very sure about that)? If this is true, then we need a CAM to let store buffer snoop the coherence,
   adding extra complexity (although the store buffer is already more or less a CAM for store-load forwarding).

This paper proposes InvisiFence, a cache and microarchitecture design for enforcing stronger memory ordering on weakly
ordered architectures. 
Previous proposals for implementing strong memory consistency models often suffer from performance overhead and/or 
design complications.
The paper gives two examples. In the first example, special hardware structures such as load queue and store buffer 
are added to the microarchitecture for tracking local memory ordering, and the pipeline is stalled when the commit of 
certain memory operations may lead to a violation of the consistency model. This approach always assumes pessimistically
that a violation will definitely occur, when the local ordering of loads and stores do not match the model's definition.
In the second example, processors are allowed to execute out-of-order memory instructions, but they continuously perform
after-retire speculation in the unit of consecutive instruction chunks. In continuous after-retire speculation, although instructions have been retired and removed from the ROB, the cache blocks accessed by these data are tracked in the private cache or by a signature, such that they are still speculative.
A snapshot of the register file is also taken when the speculation begins.
Memory instructions to different addresses can be executed in arbitrary order, as long as no external viewer (e.g.,
other processors, or bus agents) 
The speculation commits regularly if no ordering violation is observed by external viewers, which can be detected by
monitoring the read and write set of the current speculation, or proactively sending the current write set to all other
processors for invalidation.
On commit, all speculatively accessed cache blocks are "released" by clearing the speculative bit.
If, however, a speculation instance collides with another speculation, or it is violated by another processor's 
memory request, one of the two speculations must abort, and roll back to the previous checkpionted state, to avoid
any observable consistency model violation.
In practice, the above mechanism requires large amount of hardware resources, including a new coherence protocol, 
extra hardware structures for holding the speculative states, or significantly change the way a cache or an on-chip
network functions.

InvisiFence adopts the second approach. The dynamic execution flow is divided into speculative chunks in the runtime, 
which can begin and end at arbitrary boundaries, except for instructions whose effect cannot be rolled back
(e.g., I/O instructions, uncachable writes), in which case speculation must commit, and execute the instruction
non-speculatively. 
The hardware ensures that all loads and stores within a speculative chunk appear as a single, atomic unit to external
viewers, such that these viewers cannot (1) observe any intermediate state in the middle of the chunk by reading dirty
data generated in the chunk before speculation ends; (2) establish any dependency with an uncommitted chunk by writing
to its working data. 
If these two can be achieved, then speculative chunks are always committed with a global ordering, just like individual 
memory instructions in sequential consistency model, such that memory instructions between chunks are ordered by the 
real-time order the belonging chunks commit., and that instuctions to different addresses are unordered within the
same chunk. The latter does not violate the consistency model, since no other processors may observe the internal
states of a chunk.

The paper assumes the following system architecture. The base system only implements the most relaxed memory consistency
model. Loads and stores are issed when they are ready, and executed as soon as possible. No load queue is present for
tracking load ordering, meaning that loads can reorder with each other. A store queue and store buffer, however, is 
attached to the store unit for tracking store addresses and status. 
Store operations are committed directly into the store buffer with the address and data. The store buffer is drained 
for maximum throughput, not necessarily FIFO, indicating that store operations may be inserted into the L1 in arbitrary 
order (stores that hit the L1 is usually inserted first, but non-hitting stores should also be given a chance to avoid 
starvation). Store-load forwarding is also performed in the store queue and store buffer to maintain correct program 
semantics.
Besides that, no ordering between memory operations are enforced, making the memory consistency model the most relaxed
among all possible design choices.

The paper then proposes the following hardware changes for InvisiFence. First, all cache blocks in the private hierarchy
(L1 only, or L1 + L2) are extended with two bits, one for speculatively load, and another for speculative store. Second,
Store buffer entries are also extended with a speculative bit for marking speculative stores. When a cache block is 
accessed by a memory operation under speculative mode, the corresponding bit is set for tracking the working set of the
current speculation. These blocks and entries can be flash invalidated on an abort operation, or be committed by flash 
clearing the speculative bits.
Lastly, as in previous post-retire speculation designs, a register file snapshot is added to keep a copy of all 
on-chip physical and special purpose registers. When speculation begins, the current non-speculative state is copied
to this snapshot, and when a speculation aborts, the snapshot is copied back to the register file for recovery.

We next describe InvisiFence's speculative operations. On a speculative load, the load instruction is executed by the
load unit as soon as it is issued. The load unit will send a request to the L1 cache for accessing a cache block. When
the cache block is brought into the L1 cache, the speculative load bit will be set (or just set it, if the block 
already exists). The paper also suggests that, if the pipeline maintains a load queue (which is not required by the 
baseline design, but still good to have), and snoops GETX requests received by the L1, the cache block's speculative
load bit can be set only when the instruction commits in the ROB, in which case it ceases from being tracked by the ROB
(nevertheless, always setting the bit on execute will ensure correctness).

On a speculative store, the store instruction is first entered into the ROB and the store queue, and later moved
to the store buffer after it commits, waiting to be issued to the L1.
When the store is issued to the L1, the cache controller first checks whether the current block in L1 is dirty, and
non-speculative. If true, then the dirty block is written back before the store is applied. This is to retain a 
pre-speculation copy of the block as recovery data just in case the speculation aborts.
The speculative store will also set the speculative store bit on the block, if not already set.

Consistency violations are detected by checking incoming coherence requests against speculative bits in the L1 cache
and the store buffer (the load queue, if present, should also be checked). 
A violation occurs, if a speculatively read block is requested for write, or a speculatively written block is requested 
for either read or write.
A violation will casue an immediiate abort of the current speculation, or an attempted commit, as we describe below.

On commit operation, the pipeline first stalls briefly waiting for the store buffer to drain, since commited 
instructions in the store buffer are still part of the atomic speculative working set, but not yet visible to other 
processors.
Then the L1 controller flash-clears the speculative bits of all entries in the L1 cache, committing the working set
atomically.
Note that during the commit process, no instruction in the pipeline may bypass the current speculative chunk.

On abort operation, the L1 controller flash-invalidates all speculatively written blocks, and flash-clears all 
speculative bits. In the meantime, the pipeline is also flushed, and the register file snapshot is restored to the 
register file. The pipeline will start fetching instruction from the original point where speculation begins. 

Speculation commits after the chunk size exceeds a threshold, or when a violating request is detected, and the processor
decides to commit first before serving the request. In the latter case, the cache controller will deter the request
for a limited number of cycles, and attempt the commit sequence. If commit succeeds, the request can be handled 
normally. Otherwise, the current speculation have to abort, before the request is served using pre-speculation data, to 
avoid obstrucing overall progress.
Speculation is also forced to commit (or abort, if commit is not possible, e.g., when an atomic instruction cannot
be included in a single speculation) if a speculative L1 cache line is about to be evicted, in order to avoid losing
track of speculatively accessed lines. 

The paper proposes two policies for invoking speculation. In the first policy, speculation is only invoked when the
processor deduces that a violation might happen for the current consistency model. For example, for RMO, speculation
begins when a memory fence is seen in the instruction flow, and instructions after the fence is speculatively executed,
and only committed when the fence retires.
For TSO, speculation begins when a store is about to bypass the previous store, or when two loads are issued 
out-of-order. The speculation should ensure that either stores or loads are executed as a single atomic unit such
that the reorder is not visible to external viewers.
For SC, speculation begins whenever an reordering is about to occur.

The second scheme requires that the processor continuously speculate, except when the instruction has side effects
and must be executed in non-speculative mode. This mode may incur excessive overhead by frequently committing
the chunk, which stalls the pipeline and drains the store buffer. To address this, the paper proposes that two
copies of the register file snapshot be prepared. While the current speculation is being committed, the next speculation
begins immediately, overlapping execution with speculation commit.
