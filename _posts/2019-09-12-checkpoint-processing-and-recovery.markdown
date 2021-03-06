---
layout: paper-summary
title:  "Checkpoint Processing and Recovery: Towards Scalable Large Instruction Window Processors"
date:   2019-09-12 09:09:00 -0500
categories: paper
paper_title: "Checkpoint Processing and Recovery: Towards Scalable Large Instruction Window Processors"
paper_link: https://ieeexplore.ieee.org/document/1253246
paper_keyword: ROB; Microarchitecture; Register Renaming
paper_year: MICRO 2003
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

**Highlights:**

1. The register reclamation algorithm with ref count is an improvement over the previous scheme. In these schemes, registers 
   are only reclaimed when the renaming checkpoint commits, while in fact they can be reclaimed when all instructions using them
   as source operands have been issued and after all checkpoints that actually have this register as an active register commit.

This paper proposes a ROB-less microarchitecture design which uses snapshots and register reference counting to
replace the regular ROB-based in-order commit scheme. The design decision was made based on the fact that future 
generations of processors must have large instruction windows to exploit program ILP. The paper identifies two
factors that may affect the performance of an out-of-order processor with ROB and in-order commit. The first factor
is branch misprediction recovery time. When the processor mis-speculates on a wrong path, the branch instruction
should be executed and the execution be recovered from the current path as quickly as possible. This, however, is not
always possible with in-order commit, due to the fact that the register renaming table must be restored to the 
exact state before the branch instruction, after which recovery can begin (e.g. flush the pipeline, invalidate 
instructions on the wrong path, and load the PC with the correct path). The longer this takes, the larger the 
penalty of misprediction will be. For a large ROB, as we will see in the following paragraphs, the cost of restoring
the renaming table to a previous state proportionally grows with the ROB size. The second factor is the number of 
physical registers. As the number of in-flight instructions increase in the instruction window, the number of 
physical registers needed to hold the temporary values also increase. Simply adding more registers into the register file
does not always work, since the register file access time is often on the critical path. In addition, register files are 
usually multi-ported. Adding more registers is likely to incur intolerable area and power overhead of the access logic.

This paper lists three schemes that are commonly used by previous proposals. The first scheme uses a backend register 
renaming table to reflect the current architectural state as instructions commit at the head of the ROB. Here "current state"
is defined by all committed instructions. The backend register renaming table is only updated when an instruction commits. 
The corresponding logical to physical mapping is updated according to the committing ROB entry. When a branch misprediction
is detected, the frontend is stalled until the branch instruction reaches the head of the ROB, after which the 
backend renaming table is copied to the frontend. At this moment, the content of the backend renaming table is exactly
the state after the branch is executed. Execution could resume after the renaming table is copied. 

In the above scheme, even when a branch has known to be mispredicted, the pipeline must wait until all older instructions
than the branch are committed. If a long latency instruction is before the branch in ROB, this will take many cycles
for the pipeline to recover. This delay, however, is unnecessary, since the execution of instructions in the backend 
should not block the frontend from fetching instructions on the correct path. As an improvement, a hardware ROB walker
is introduced to quickly apply the changed to be made to the renaming table onto the backend table. The ROB walker starts
from the current head of the ROB, and proceeds until it reaches the mispredicted branch (note: if there is an exception
then we should handle exception first). After all changes are applied, the backend renaming table is copied to the frontend.

On the other hand, instead of replicating a renaming table at the backend, some other researchers propose walking the ROB 
from the tail, and undoing all changes that have been made to the frontend renaming table. This is done as follows. When
an instruction is renamed, the hardware saves both the before register and the after register in the ROB entry allocated
to the instruction. The before register saves two purposes. First, if the instruction commits, the before register can
be released since its content is no longer needed. Second, if the instruction is on the wrong path, then the ROB walker
uses this field to undo the changes this instruction has made to the renaming table during decoding. Execution could 
resume after all instructions younger than the mispredicted branch are undone.

In all above three schemes, the branch misprediction panalty is directly related to the size of the ROB. In the first scheme,
it depends on the number of cycles required to commit instructions before the branch. In the latter two schcmes, the penalty is 
dependent on the number of instructions older or younger than the branch. On a large ROB, none of them can achieve constant-time
misprediction recovery, which motivates this paper's checkpoint design.

This paper assumes a mapping table implemented with regular SRAM, having one entry for each logical register. The physical 
register number currently mapped to the logical register is stored in the entry. Although not mentioned, it is assumed 
that a free list manages all free physical registers, which can be implemented as a bit vector, one bit per physical 
register. Each physical register also has a one bit flag to indicate whether the physical register has been renamed
in the current checkpoint. Physical registers are reference counted. Although the paper did not mention the width of 
the reference counter, for a large instruction window, allowing the counter to potentially count all instructions in the 
window is not optimal, since in practice only few instructions will refer to the same logical register. We will describe 
the usage of reference counters and renamed bits below.

The creation and commit of checkpoints resemble those in other checkpointing proposals. In general, there is a checkpoint 
buffer sitting at the frontend which consists of several entries. When a checkpoint is taken, the logical to physical 
mapping, the free list bit vector and the renamed bit are copied to a new entry of the checkpoint buffer. A checkpoints also
has a reference counter that counts the number of uncommitted instructions in the checkpoint. When an instruction is dispatched,
the reference counter is incremented, and when an instruction is completed in the backend, the counter is decremented.
A checkpoint could commit if (1) the value of the counter reaches zero; (2) it is at the head of the checkpoint buffer, and 
(3) it is not the only checkpoint in the buffer. A checkpoint commits by deleting the entry from the queue, and releasing 
all data generated by stores in the store queue to the cache hierarchy. 

This paper suggests that checkpoints be created at two conditions. The first condition is when a low confidence branch is 
predicted. A low confidence branch is likely to be predicted wrong, which results in the roll back of the including checkpoint
and all checkpoints after. The paper proposes using a simple 4-bit saturate counter based prediction scheme to decide if 
a branch is low confidence and whether a checkpoint should be created. The other condition is before the number of instructions
in the current checkpoint becomes too large. In this case, if the checkpoint is rolled back, all instructions in the 
checkpoint have to be re-executed, resulting in waste of cycles. 

Registers are released when it can never be accessed in the future. To achieve this, several conditions must be met. First,
the register must not be accessible in uncommitted checkpoints, because if the checkpoint is rolled back later, the register 
may be used again during the re-execution of the checkpoint. Second, when a physical register is released, it must have 
already been renamed, because otherwise the physical register is still the active register for a logical register, which
can be accessed in the future execution. Third, a register can still be accessed after it is renamed, due to the fact
that registers are only accessed when instructions are issued to functional units, which is performed out-of-order (the 
instructions that use the register can be before the instruction that redefines the register in program order, at the issue 
time of which the physical registers have already been renamed). To satisfy these three conditions, physical registers 
are reference counted to ensure that they are never released before possibly accessed by an instruction. When instructions
finish register renaming stage in the pipeline, we increment the counter for the physical registers that provide source 
operands. When such instructions are issued, after reading the source operand values, the corresponding counters are 
decremented. To further ensure that checkpoints will not access an invalid register when it rolls back, when a new checkpoint
is created, counters for all active physical registers (i.e. those in the current logical-to-physical mapping) at the time
of creation are incremented. Similarly, when a checkpoint is released, these counters are decremented. When an instruction
renames logical register A from physical register X to Y, the "renamed" bit of register X is also set. A physical register 
can be released, if the "renamed" bit is set, and if its reference counter is zero. 