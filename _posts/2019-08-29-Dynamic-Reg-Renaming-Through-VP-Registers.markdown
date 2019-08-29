---
layout: paper-summary
title:  "Dynamic Register Renaming Through Virtual-Physical Registers"
date:   2019-08-29 04:27:00 -0500
categories: paper
paper_title: "Dynamic Register Renaming Through Virtual-Physical Registers"
paper_link: https://ieeexplore.ieee.org/document/650557
paper_keyword: Register Renaming; Microarchitecture
paper_year: HPCA 1998
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Virtual-Physical Register in order to optimize register renaming. The paper points out that the current 
register renaming scheme are often sub-optimal in two aspects. First, physical registers are only freed when the renaming
instruction commits, due to speculation and presice exception. For example, if speculation fails, all instructions after the 
mis-speculated instruction will be squashed. If we released a physical too early (i.e. before the renaming instruction becomes
non-speculative), another consumer instruction of the logical register may be issued, which reads an undefined value. Similarly,
to provide precise exception, the state of the logical register file must match the one in serial execution when the 
triggering instruction raises an exception. If the physical register is released before the renaming instruction commits,
it is possible that we read the released physical register as part of the architectural state when the execption is raised.
The second problem with the current scheme is that physical registers are allocated during the decode stage in the front-end,
while only actually needed before a value is generated and written back. Holding a physical for a prolonged time during the 
waiting and execution period may result in a shortage of physical registers, stalling the front-end pipeline, while instructions
already allocated a physical register do not use them until the last cycle of execution.

This paper made an important observation that regiater renaming in fact servers two distinct purposes. First, by renaming
logical registers of the same name to physical registers of different names, we enable dependency tracking between instructions,
which constitute the core of out-of-order execution. Data-flow dependency tracking works on today's superscalar using the 
name of the physical register, but not the content. This observation is confirmed by the fact that when an instruction commits,
we only broadcast its destination physical register name to waiting instructions in the window, rather than the content. 
The scheduling decision of instructions in the windows is also made merely based on whether they have received the operand
name through broadcasting, instead of checking the value. The second purpose of register renaming is to allocate storage for
completed instructions. The allocated physical register acts as a temporary storage for the produced values. The lifetime of
this temporary storage starts from the moment a value is produced till the commit of the renaming instruction to the
physical register. The paper notes that using physical register for both dependency tracking and value storage is 
apparently a mismatch, since the former is needed right after the decoding stage (and that is the reason why register
renaming must happen before the issue stage in conventional schemes), while the latter only requires a physical register
to be allocated at the last cycle of execution.

The paper proposes that, instead of allocating storage and performing dependency tracking at the same time under the 
abstraction of physical registers, we decouple these two tasks into two separate abstractions. Dependency tracking 
is achieved with a set of new registers, called Virtual-Physical Registers (VPR), which are used as a way of tagging
data-flow dependencies between instructions. Storage allocation is achieved using regular physical registers (PR), but 
instead of allocating a PR for every value producing instruction at the decode stage, we only allocate PRs before they
are really needed.

This scheme resembles virtual memory and demand paging, in which an extra level of indirection is added on to the 
physical address space, such that memory accessed are always made with virtual addresses. A virtual address is just
a "symbol" for ensuring that different data are allocated on distinct locations. A virtual address can be backed by
nothing, and mapped to a physical address only when it is actually accessed. In our context, physical registers are 
analogus to physical addresses, while virtual-physical addresses are analogous to virtual addresses. When dependency
tracking is needed such that instructions do not overwrite each other's result out-of-order, we allocate virtual-physical
registers. Only when a value is produced (which can be many cycles later) do we allocate a physical register to back the 
virtual-physical register. 

The Virtual-Physical renaming scheme requires two data structures. The first data dtructure, called the General Mapping 
Table (GMT), maps a logical register (LR) to both the VPR and the PR. An extra bit is used to indicate whether the VPR has
been allocated a PR or not. This bit is set after an instruction has produced value and written back the result to the PR.
The second data structure is called Physical Mapping Table (PMT), which maps VPR to PR. The PMT resembles a page table:
If a VPR has not been allocated a PR, the entry will not store a valid PR identifier. Note that the paper assumes there
would be more VPR than PR, since VPRs do not need to be backed by anything, while PR consume energy and area on the chip.

Two modifications are also made with instruction window and ROB. In the instruction window, we now store the VPR or PR for 
source operands, and use a ready bit for each to determine which one it is. The destination VPR is also stored in the window. 
In the ROB, we store the logical destination register and the previous VPR the destination register is mapped to when this 
instruction is renamed at decode stage. This field is essential for recovery from mis-speculation.

The renaming process works as follows. When an instruction enters the decoding stage (we assume it has an integer 
destination register), we allocate a VPR to the instruction without a PR. The source operands are first located 
from the GMT as in a regular scheme. If the GMT indicates that a logical register has been allocated both VPR
and PR, then the source operand's register just uses the PR, and the ready bit in the window is set. Otherwise, the 
ready bit is cleared, and the VPR is copies into the instruction window. Then the hardware renames the destination logical
register to a newly allocated VPR as follows. First, the current value of the VPR in the GMT is copied into the ROB entry 
of the instruction. Then, a new VPR is allocated from a free list, and the GMT entry is updated with the newly allocated
VPR. The PR and the bit is cleared since no physical register has been allocated. The instruction is then sent into the 
window and will be scheduled when both ready bits are "1". When the instruction is executed