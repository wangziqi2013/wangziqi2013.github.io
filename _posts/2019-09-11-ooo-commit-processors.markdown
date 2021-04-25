---
layout: paper-summary
title:  "Out-of-Order Commit Processors"
date:   2019-09-11 23:47:00 -0500
categories: paper
paper_title: "Out-of-Order Commit Processors"
paper_link: https://ieeexplore.ieee.org/document/1410064?arnumber=1410064&tag=1
paper_keyword: ROB; Microarchitecture
paper_year: HPCA 2005
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

**Highlights:**

1. Treating multiple instructions as a "complex" instruction and only commit them together or roll back together is 
   a very nice optimization technique (optimization by coarsening).

2. The paper makes an interesting observation that by using a CAM for register renaming, only two of the three control
   bits need to be saved.

**Questions**

1. The paper failed to mention why register renaming at the end of checkpoint i needs to be delayed to the end of 
   checkpoint i + 1.

This paper explores the design space for out-of-order instruction commit in out-of-order execution, superscalar processors.
Conventionally, out-of-order execution processors have a FIFO reorder buffer (ROB) at the backend which is populated when 
instructions are dispatched to the backend. Instructions are inserted into the ROB in the original dynamic program order,
and remain there until the execution is finished. Instructions are only retired in the ROB when they are currently at the 
head of the ROB (i.e. the oldest uncommitted instruction). Instructions commit by writing their results back to the register 
file (in practice this can happen earlier than instruction commit), moving the store queue entry into the store buffer, or 
forcing the processor to restart on the correct path on a branch mis-prediction.

As the number of instructions in the instruction window keep increasing for better ILP, the ROB has become a bottleneck 
in the backend pipeline. There are two reasons for this. The first reason is that ROB forces instructions to commit 
in the program order, which decreases instruction throughput if the head of the ROB is a long-latency instruction,
such as loads that miss the L1 cache. The second reason is that the hardware cost for supporting an ROB with thousands
of entries is unacceptable with today's technology. The large ROB design simply cannot be achieved with reasonably 
energy and area budget.

The paper observes that, on modern processors where register renaming is used to avoid WAR and WAW conflicts, the ROB
is no longer necessary to ensure correctness of execution in absence of exceptions and mis-speculation (without register
renaming, the ROB is used as a temporary physical register). Instead, the ROB is just used as a reference for undoing changes
when exceptions happen, or when a branch is mis-speculated. In addition, the undo information is often stored in the 
ROB when an instruction has a destination register. The previous entry for the logical register is saved in the ROB
entry of the instruction. When the current instruction commits, the previous physical register can be released, since 
it is guaranteed that no more instruction can possibly access its value. 

Without a ROB for remembering instructions in their program order, processors take "checkpoints" regularly to save the 
execution state for a later restart. This paper assumes a CAM-based register renaming scheme, in which a CAM is used
to map from logical registers to physical ones. The CAM has an entry for each physical register. The content stored in the 
CAM are the ID of logical registers and three control bits. The first control bit is "valid" bit, which indicates whether
the entry is the most up-to-date logical-to-physical register mapping. The second bit is "free" bit, which indicates 
whether the current physical register is free to use. When a new physical register is needed, the hardware logic searches 
for an entry whose "free" bit is set, and then clear the bit. The third bit is "future free" bit, which indicates whether
the corresponding physical register has been renamed in the current checkpoint, and can hence be freed at the end of the 
checkpoint if it commits successfully (this is consistent with the register release scheme above). The renaming logic
guarantees that only one of these three bits will be set, i.e. at any given time, a register must be either active, or 
free, or "future free" which means that it is inactive but still holds value that might be read by some instructions 
(i.e. out-of-order instructions). 

For CAM-based renaming scheme, a checkpoint consists of only two of the three control bits for each register. The paper 
suggests that we save the active and future free bits for every physical register, and infer the free bit on a checkpoint 
recovery. Compared with mapping table based scheme in which a mapping table stores the physical register number for each
logical register, the CAM-based scheme allows significantly smaller checkpoints due to the fact that the logical register 
ID does not need to be saved. Not saving the actual mapping will not result in using an invalid physical register as long 
as the logical register ID is retained after the physical register becomes inactive. A checkpoint can always restore to 
the same logical-to-physical mapping, since the entry will not be modified before the physical register is released, which
can only happen when the current checkpoint commits. 

The pipeline works as follows. The frontend maintains a checkpoint buffer, which is a FIFO queue holding the two sets of 
control bits and the reference counter. At any moment of operation, there is always at least one checkpoint in the buffer. 
The current checkopoint is the tail (newest) checkpoint, whose checkpoint ID is its index in the queue. When a new 
checkpoint is added, a slot is allocated from the tail of the queue, and the current content of the renaming table is 
copied into the slot. Furthermore, the "future free" bits are cleared, and the reference counter is also initialized to 
zero. When an instruction is dispatched, the current checkpoint ID is also stored in a field of the instruction window. 
Renaming and issuing are unaffected and both work the same as in a ROB-based processor. When an instruction completes, the 
checkpoint ID is used to find the checkpoint, whose reference counter is then decremented. During this process, no ROB is 
used to maintain the relative ordering of instructions, and therefore, instructions can complete out-of-order without 
blocking others in the ROB. Store instructions must be kept in the store queue and not released to the memory system until 
the checkpoint commits, because otherwise, if the checkpoint is rolled back, the memory state will be inconsistent with 
the processor state.

A checkpoint commits When: (1) the reference counter of a checkpoint reaches zero; (2) the checkpoint is at the head of 
the queue (i.e. oldest uncommitted checkopint), and (3) it is not the only checkpoint in the queue. We commit the current 
checkpoint simply by releasing the buffer entry. In addition, stores are released to the store buffer since the checkpoint 
can never be rolled back. Physical registers that are renamed (i.e. whose "future free" bits are set in the current checkpoint) 
by the current checkpoint can also be released. This, however, can be tricky, because the current rename map may have 
already changed as the pipeline keeps decoding new instructions for later checkpoints. One way of doing this is to postpone
physical register release to the commit point of the next checkpoint, since the next checkpoint stores "future free"
bits when it becomes the youngest checkpoint, at which point these "future free" bits encode the set of registers that
are renamed in the current checkpoint. The paper admits that this may harm performance, since physical registers are held
longer than they should be. To avoid performance degradation, although not mentioned in the paper, when a checkpoint commits,
the hardware may just extract the "future free" bits from the next checkpoint (there must be one, otherwise the current 
checkpoint must not commit) and then release the physical registers.

When a branch misprediction or exception is detected by the commit logic, the corresponding checkpoint is located using 
the checkpoint ID field of the instruction. The pipeline is flushed, and system state is restored to the beginning of the 
checkpoint in which the exception or misspeculation happen. Entries older than the faulting checkpoint are deleted from 
the checkpoint buffer. The renaming table is also restored by copying the "valid" and "future free" bits back to the CAM.
The hardware can infer the "free" bits by simply taking a NOR of the other two bits. The processor then resumes execution
from the PC stored in the checkpoint. In the case of a branch misprediction, the branch is not predicted again, but rather
just assumes the alternate direction. In the case of an exception, the hardware takes a checkpoint when the instruction that
caused the exception is executed, which is used as the precise architectural state when the exception is raised.

The paper suggests that a checkpoint be taken under the following three conditions. The first condition is branch. Although
most branches are predicted correctly on modern hardware, saving a checkpoint at every branch will not incur too much space 
overhead, since a checkpoint has the overhead of just two bits per physical register. The second condition is when the 
number of instructions in the current checkpoint exceeds a certain threshold. This is to reduce the penalty of checkpoint 
recovery, since the larger the checkpoint is, the larger penalty there will be to re-execute from the beginning of the 
checkpoint. The last condition is when the number of stores in the store queue exceeds a certain threshold. This is to
avoid the store queue from becoming a source of structural hazard, since data written by store instructions within a 
checkpoint are only released to the cache hierarchy when the checkpoint commits. 