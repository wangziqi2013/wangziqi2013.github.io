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