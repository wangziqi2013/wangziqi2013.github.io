---
layout: paper-summary
title:  "Efficient Register Renaming and Recovery for High Performance Processors"
date:   2019-09-13 21:18:00 -0500
categories: paper
paper_title: "Efficient Register Renaming and Recovery for High Performance Processors"
paper_link: https://ieeexplore.ieee.org/document/6558839
paper_keyword: ROB; Microarchitecture; Register Renaming
paper_year: VLSI 2014
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a hybrid register renaming scheme using both RAM and CAM to achieve low latency, low power consumption
and fast branch misprediction recovery. Conventional register renaming schemes either use RAM-based or CAM-based mapping 
table to encode the logical-to-physical relation. The paper observes that, however, that both schemes have inefficiencies
that can become the bottleneck of the pipeline. For RAM-based design, branch misprediction recovery and precise exception
both require that the mapping table be restored precisely to a previous point during execution. Modern pipelined processors, 
however, allow renaming of speculative instruction in the frontend to be performed in parallel while the branch (or faulty) 
instruction is still executed in the backend. The changes made by these mis-speculated instructions must be undone before 
the branch target can be fetched to avoid using the worng physical register. For CAM-based design, the renaming state before
the branch instruction can be restored easily in constant time by checkpointing the renaming table into a checkpoint buffer.
When the branch is known to be mispredicted, the checkpoint is copied to the renaming table, which does not require walking
the ROB, but adds extra checkpoint buffer cost. In addition, register renaming needs to access the multi-ported CAM, the 
latency and power consumption of which can be large.

The paper reviews two different recovery schemes in detail for RAM-based renaming algorithm. In such a design, A RAM structure 
indexed by the logical register number is used as the mapping table. For every logical register, there is an entry in
the RAM structure which stores the physical register mapped to this entry. A free list bit vector maintains currently
unused physical registers. When an instruction is decoded, the renaming logic first reads the physical register corresponding
to the source operands, and then allocate a new physical register for the destination logical register. The mapping table
entry for the destination register is also updated to reflect the change. An ROB is also assumed to be at the backend
and buffers instructions in the dynamic program order until they are committed. When a branch misspeculation is detected
at the final stage of backend execution, the ROB is notified of this event, and depending on the recovery scheme, three
different actions can be taken. In the simplest recovery scheme, we add a field into the ROB to remember the previous 
physical register that is replaced by the newly allocated one. When a misprediction is detected, the pipeline stalls and 
waits for the branch instruction to reach ROB head, at which time all instructions older than the branch have been committed
and results are written back. Then a hardware walker is invoked to walk the ROB from the tail until the branch instruction
(i.e. ROB head) is reached. For each ROB entry within this range, the physical register allocated to it is released,
and the previous mapping is restored to the logical destination register. After this process completes, execution could 
resume at the correct branch address. Resolving branch misprediction only at commit point, however, is not optimal, since
the misprediction can in fact be detected as soon as the branch instruction finishes execution. This is especially harmful
if a long latency instruction older than the branch blocks ROB commit. To allow mispredictions to be resolved before the
branch commits, some proposals use a backend renaming table which is only updated by committed transactions. The backend 
renaming table has the same structure and interface with the frontend renaming table, and it reflects the execution
state of only committed instructions. With a backend renaming table, when the branch misprediction is detected, the ROB
walker first copies the backend renaming table to the frontend, and then walks from the head of ROB to the beanch instruction,
and applies changes to the frontend renaming table as if it were applied to the backend table. Then the ROB walker walks 
from ROB tail to the branch instruction to restore mapping entries using the undo image in the ROB. In the paper, it is 
reported that the optimized design can reduce average branch misprediction panalty from 36 cycles to 15 cycles. 

The paper also introduces its baseline checkpointing design with a CAM-based mapping table. The mapping table has an entry
for each physical register, which stores the logical register currently mapped to the physical register. Only a single
control bit is needed per physical register, which indicates whether the physical register is currently active, i.e. whether
the mapping is the current mapping to be used for source operand renaming. This bit serves as a "reference bit" of the physical
register, the state of which encodes whether the physical register can possibly be used in a checkpoint. No explicit reference
counter is maintained for physical registers. As in many other checkpoint based designs, a checkpoint buffer which is 
maintained as a circular FIFO queue provides storage for checkpointed renaming tables. Only the control bits are copies into
the table when a checkpoint is taken. Each checkpoint is also associated with a reference coutner, which is incremented 
when an instruction is decoded, and decremented when instructions commit. A checkpoint commits when it is at the tail 
of the FIFO queue, and all instructions in the checkpoint are committed. Physical registers are considered as free, if 
the physical register has no control bit set in any of the currently uncommitted checkpoints, including the current one
(i.e. the one stored in the mapping table; in fact the buffer and mapping table can be implemented as a monolithic structure,
with the control bits maintained as a circular queue and the mapping maintained as a CAM). The allocation logic simply tests
all bits for a certain physical register with a NOR gate. An output of "1" indicates that the register is not referred to in
all uncommitted checkpoints, which can be allocated to a new instruction without worrying about the same register
being accessed by a different instruction after a roll back. On a source operand renaming, the decoding logic selects 
the entries in the CAM with the logical register as values, and then uses a priority decoder to output the final physical
register number whose control bit is "1". Checkpoint restoration and resumption are similar to prior proposals.

This paper proposes combining both RAM-based and CAM-based scheme to leverage the best of each and avoid the disadvantages.
To reduce recovery penalty, the renaming table is implemented with a CAM, and the checkpoint and recovery scheme is exactly 
as described in the last paragraph. To avoid a long latency associative search in the CAM, a RAM-based renaming table is 
used as a fast cache for the CAM mapping table. Each entry of the RAM mapping table also has a valid bit to indicate whether
the entry contains valid physical register number. The renaming process is then divided into three stages. In the first stage,
the hardware checks whether the source operands are cached by the RAM by directly indexing into the RAM table. If the result
is a hit, then no more table probing is needed, and the renaming logic do nothing in the next two stages. If the result is 
a miss, then in the second stage, the CAM table is accessed to fetch the mapping. And then in the third stage, the RAM
is accessed again to be updated with the latest mapping information (similar to a cache miss; some entries may also get evicted).
Renaming the destination register is also a three-stage process. In the first stage, a new physical register is allocated 
from the CAM by performing an associative search. The allocated physical register number is written into both the CAM
and the RAM (both using indexed access because we know both logical register number and newly allocated physical register 
number). In the meantime, the current mapping between the logical register and physical register is canceled by probing 
the RAM with the logical register number. If the result is a hit, then the physical register name is directly used to index 
the CAM in the second stage, and the hardware clears the control bit of the physical register. Otherwise, we need to perform 
an associative search to locate the current physical register of the destination logical register, and then update the 
entry. Note that during this process, if an instruction has one of the source operand the same as one of the destination
operand, the allocation will be incorrect, since it is possible that the source operand is read at the second stage, 
while the new mapping from the destination to the physical register is written in the first stage. In this case,
the source operand will be renamed to the newly allocated physical register, rather than the old value. This case should 
be easy for hardware to detect and fix, by checking whether the source and destination are the same register, and then
read out the old value in the first stage of destination renaming before updating both tables.