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