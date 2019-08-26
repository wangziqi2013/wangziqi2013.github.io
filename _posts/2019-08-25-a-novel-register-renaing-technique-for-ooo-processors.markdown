---
layout: paper-summary
title:  "A Novel Register Renaming Technique for Out-of-Order Processors"
date:   2019-08-25 20:31:00 -0500
categories: paper
paper_title: "A Novel Register Renaming Technique for Out-of-Order Processors"
paper_link: https://ieeexplore.ieee.org/document/8327014
paper_keyword: Register Renaming; Microarchitecture
paper_year: HPCA 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a new register renaming algorithm which takes advatage of the observation that some values are only 
used once after they are produced. In traditional register renaming algorithms, a new physical register is always allocated
for instructions that produce a value, such that in the case of WAR dependency, the writing instruction can actually be 
scheduled before the reading instruction, hence increasing parallelism of the OOO pipeline. A physical register R can 
only be released when the instruction that renames R become non-speculative, and when all consumers of R have finished 
reaading the value from R (i.e. after they are issued from the instruction window). In practice, R is often released 
when the renaming instruction commits, at which time it must be non-speculative, and all earlier instructions must have
already also been committed since the ROB commits instructions in the dynamic program order.

This renaming scheme, however, are over-conservative when some values are only used once. For example, given that instruction
i is the last instruction that uses value stored in physical register R. After i reads from R at issue stage, the physical
register R can be released right away, because it is guaranteed that no one else can read from it even if R has not been 
renamed by another instruction. Even better, if such instruction i can be identified as early as it is decoded, and if i
produces a value itself, then the renaming for instruction i could be as simple as assigning R as a destination register 
to i, saving an extra allocation from the physical register file. 

The paper identifies that, as the instruction window keeps scaling on newer systems, the size of the physical register file
must keep growing as well, to avoid stalling the processor at decode stage as a result of lacking registers. Scaling the
physical register file, however, is a difficult task, since register files are generally multi-ported. Adding extra registers
may increase the space overhead and power consumption exponentially.

This paper proposes extending the register file as follows. Each physical register is extended with two extra fields.
The first is a single bit flag to indicate whether the value of the physical register has been read (note that we assume
all instructions read from the register file at issue stage, rather than reading from the broadcasted value when the 
dependent instruction commits). It is cleared whenever the physical register is allocated to an instruction, and set when
an instruction reads it in the issue stage. The second field is a 2-bit counter, which represents the version of the 
content of the physical register. This 2-bit counter is critical for identifying which version of data is read when an
instruction commits and wakes up dependent instructions in the instruction window, because otherwise, if instruction
i1, i2, i3 both read from and write into physical register R, then when i1 commits, it will broadcast to the instruction
the status change of R. If the version of R is not specified in this broadcast, both i2 and i3 might be awaken since they
both have a source register R. As indicated by the above example, when an instruction is allocated register R as the 
destination register, it takes the counter value as the version of data to be written (and stores it in the ROB), and 
increments the counter. When an instruction reads R as a source operand, the current version should also be stored into
ROB as the version of data. When an instruction commits, it broadcasts the name of R together with the version. Only
those whose in-ROB register names and versions match the broadcasted value will be woken up.

The proposed register renaming scheme works as follows. When an value-producing instruction enters the decoding/renaming 
stage of the pipeline, we first check whether any of the source operands is accessed first time after it is produced by
checking the one bit flag of the physical register. If the bit is clear, then we know the source has not been read before,
and we set the bit to notify later instructions.
If the instruction indeed is the first reader of one of its source operands, the second check is performed to see if the 
instruction is also the last reader of the same source operand. There are two cases. In the first case, the instruction's 
destination register is identical to the aforementioned source

a hardware predictor is invoked to predict whether the instruction will only have one consumers; 
If positive, the predictor also try to predict the number of sharers of the same register. Note that by saying "sharers" 
on the same physical register R, we mean (1) these instructions all produce a value, which is mapped to R, and (2) they 
all read physical register R as source operands, and (3) they are all the last consumer of physical register R. The number
of sharers are used as an optimization that we will discuss below. If the instruction is predicted to have only one
consumer and that a new physical register must be allocated, then the physical register for this instruction will be 
allocated from a special checkpointed part of the register file. Assuming that the prediction for instruction i is correct, 
when the instruction j that reads from i is decoded and if instruction i's register is from the special area of physical
register file, since it is expected that the value in R is no longer needed after j reads it, instruction j's destination 
register will be assigned as R. Recall that every time a register is reused, the version counter will be incremented and 
the one bit flag will be set. 