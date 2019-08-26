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