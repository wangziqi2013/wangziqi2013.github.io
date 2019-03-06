---
layout: paper-summary
title:  "Dual-Page Checkpointing: An Architectural Approach to Efficient Data Persistence for In-Memory Applications"
date:   2019-03-05 21:51:00 -0500
categories: paper
paper_title: "Dual-Page Checkpointing: An Architectural Approach to Efficient Data Persistence for In-Memory Applications"
paper_link: http://grid.hust.edu.cn/wusong/file/taco18.pdf
paper_keyword: NVM; Durability; Checkpointing; Copy-on-Write
paper_year: TACO 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes dual-page checkpointing, a hardware checkpointing scheme based on fine-grained copy-on-write (COW)
with low metadata and storage overhead. The paper identifies the problems of two popular checkpointing schemes, logging
and coarse-grained Copy-on-Write, which we describe as follows. Logging requires the system to duplicate every memory
write to the NVM, one for in-place updates to the home location, another for generating log entries. Excessive NVM writes
are both slow and introduce wearing. Careful optimization may move the slow log entry write out of the critical path,
and only performs logging on the first write during an epoch, but still, the overhead of writing twice is non-negligible.
Page-level Copy-on-Write, on the other hand, never updates data in-place. On an update, the page is first copied to
another location, and then the update is directly applied to the new copy. Since the old copy is intact, even if the 
system crashes halfway before commit, we can still recover to a previous state by simply discarding new pages. On commit,
the updated pages are written back to their home locations, which is done using a system transaction (which itself is 
implemented using undo logging). Page-lavel COW suffers from write amplification, since even a single byte update on
a page requires an entire page to be read and written. Even worse, COW needs two page reads and two page write for every
page updated within an epoch: One read to make the shadow copy during normal operation, one read and write during 
commit to generate the undo log entry, and one final write to flush back the updated shadow page. 

