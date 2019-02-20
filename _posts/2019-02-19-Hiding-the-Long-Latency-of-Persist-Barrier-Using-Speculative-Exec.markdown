---
layout: paper-summary
title:  "Hiding the Long Latency of Persist Barriers Using Speculative Execution"
date:   2019-02-19 17:19:00 -0500
categories: paper
paper_title: "Hiding the Long Latency of Persist Barriers Using Speculative Execution"
paper_link: https://ieeexplore.ieee.org/document/8192470
paper_keyword: NVM; Persist Barrier; Speculative Execution
paper_year: ISCA 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---  

This paper proposes speculative persistence, a microarchitecture technique that allows processors to execute past a 
persistence barrier. A persistence barrier is a special instruction sequence that stalls the processor until previous
cached store operations are acknowledged by the memory controller. It is particularly essential in NVM applications
where the system state is persisted onto the NVM to enable fast crash recovery. Many existing proposals use undo
logging, where the value of data items (e.g. cache line sized memory blocks) are first recorded in a sequential log
before they are modified by store operations. On recovery, the undo log entries are identified, and partial modifications 
are rolled back by re-applying all undo log entries to the corresponding addresses. 

This paper assumes a static transactional model. Persistence is achieved by wrapping operations within static transactions. 
Either all store operations within a transaction are persisted as an atomic unit, or none of them is persisted. On recovery,
partial transactions are rolled back using undo log as described in the previous paragraph. Transactions execute as follows.
First, locations that are to be stored into are identified, and log entries containing their old values are generated. 
Second, these log entries are flushed to the NVM by issuing a persist barrier. Next, the transaction begin record is written
and flushed into the log to indicate that after this point, dirty cache lines might be evicted back to the NVM. Then, the 
transaction body is executed as usual, during which dirty cache lines might be written back to the NVM due to eviction.
Lastly, dirty cache lines are flushed back to the NVM using another persistent barrier, after which the transaction end 
record is written and then flushed using the fourth persistence barrier. On recovery, the recovery handler reads the sequential
log in reverse order. For every uncommitted transaction in the log, it first checks whether the transaction has begun by 
locating the transaction begin record. If the log has undo log entries, but the transaction actually did not begin, these 
undo log entries are discarded, because it is guaranteed that no dirty cache lines from the transaction can ever reach NVM. 
Otherwise, undo entries are applied. 

The above transaction model requires programmers to know exactly which locations will be written before the transaction begins.
If it is not the case, two alternative models can be used. The first model is incremental update, in which the transaction 
does not log all entries at the beginning, but only writes and persists log records right before they update an item. The 
transaction begin record must hence be written and flushed at the very beginning of the transaction. In this model, the 
number of persist barriers is upper bounded by the number of store instructions in the transaction. In contrast, in the 
static transaction model, only constant number of (four) persist barriers are used. One way to allievate this issue is 
to collect as many store location as possible that are known at the current time of execution, and then log them in batches.
The second model is full logging, in which programmers leverage domain-specific knowledge of the data structure, and log 
a super set of memory locations that might be changed before the transaction body starts. For example, in a B+Tree, in
the worst case a leaf node split will cause all nodes from the root to the leaf node to split, which happens every time
the height of the tree grows by one. The logging scheme must then log every node from the root to the leaf to deal with
the possible (but rare) worse case scenario. Compared with incremental logging, only four persist barriers are required,
but potentially many more nodes than necessary are logged which may cause bottleneck if the tree is large. This paper 
assumes full logging scheme whenever static transaction is difficult.

Persistence barriers are detrimental to performance, because the processor stalls to wait for an acknowledgement from
the memory controller. In our transactional model, at least four persistence barriers are executed for each transaction,
leading to frequent stalls. To solve the problem, this paper makes three observations. The first observation is that 
execution can be performed speculatively while the processor is waiting for pcommit, as long as the state of the 
speculation is not revealed to other processors, thus defining the beginning of the speculation. The second observation 
is that some instructions cannot be executed speculatively, such as PMEM instructions (i.e. clflush, clwb, pcommit, 
clflushopt, etc.) because they cause non-undoable actions to be taken on external devices, and the processor has no
way to buffer the state changes. Luckily, the third observation is that PMEM instructions have a very flexible re-ordering 
rule: They can be reordered with most instructions except store fences, serializing instructions (LOCK- prefixed, XCHG, 
etc.) and conflicting instructions. This last two observations together define when speculation must stop, as we shall 
see later. In the following paragraphs we call the time period from the beginning to the end of speculation as an "epoch".

Persistence speculation begins when the instruction sequence "pcommit, sfence" is seen, which indicates that the processor
should stall until the memory controller sends an acknowledgement for the persistence of stores. The processor keeps executing
the instruction stream after the barrier without making available the internal states to other processors. First, the 
processor takes a checkpoint of all architectural states at that point and pushes the checkpoint into a queue. Note that
although during normal execution, persistence speculation will never be rolled back, it is possible that NVM reports an 
error as the return code of pcommit, at which time the processor should roll back to the first non-speculative point and 
raise an exception. The checkpoint is only discarded when the corresponding pcommit instruction receives an ACK. All
store operations during the speculation are buffered in a separate queue called the Speculative Store Buffer (SSB). The SSB
is checked on every load operation using the address of load, and if there is a match, the dirty data is forwarded from
the newest SSB entry having the same address rather than cache or memory. The paper noted that in a practical design, the 
SSB would be implemented using Content Addressable Memory (CAM) which has relative high latency (5 cycles). To enable 
fast lookup of the SSB to at least determine whether an address is present, the paper proposes adding a bloom filter
to accelerate address lookup on read, since most read instructions expect low latency as they are likely to hit the L1 
cache. The bloom filter is periodically cleared when there the last speculation ends and the processor enters normal execution.

Speculation may introduce unexpected reads/write conflicts with other processors, which cause the current processor to 
access inconsistent data. For example, if lock acquisition code is executed under speculation, the lock acquisition
will not actually be visible to other processors, while the current processor can execute the critical section also 
speculatively. This may cause problem, if another processor acquires the lock in non-speculative mode, and modifies a data 
structure in the critical section. In this case, the former processor may accidentally stump upon some inconsistent states 
as a consequence of the latter processor actively modifying it, which causes unexpected error, some of which being 
non-recoverable (e.g. jumps to undefined piece of code). To prevent the above from happening, the processor under 
speculation must record all cache line addresses read or written in a hardware structure called the Block Lookup Table 
(BLT). On receiving external coherence requests, the processor checks the block address again the BLT. Any conflicting
access will cause all active speculations to abort, restoring the system state to the first checkpoint. The paper also pointed
out that the roll back may happen in finer granularity, if we also store in the BLT the corresponding epoch a memory
instruction is executed. On conflits, the system state is only restored to the earliest epoch before which no conflict
is present.

During speculation, if a PMEM instruction is seen in the instruction flow, the processor reorders the PMEM instruction 
with following instructions in the instruction stream until it is unable to do so. In order words, the execution of the 
PMEM instruction is delayed by the processor, until the processor sees another instruction that cannot be reordered with
the PMEM instruction, as listed above. In this case, the current epoch terminates, and the PMEM instruction is executed 
non-speculatively by the processor. A new epoch will start after the PMEM instruction, from which point a new instance 
of speculation begins. 


Speculation terminates successfully when the corresponding pcommit instruction returns success and the epoch is the earliest
in the queue, in which case the checkpoint is discarded, and all store operations buffered in the SSB are applied to the 
cache in program order, sending coherence messages to acquire cache line permission if necessary. If the pcommit instrucrtion
returns but the epoch is not the earliest one, the epoch should not commit until it becomes the earliest epoch. 