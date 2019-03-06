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

On the other extreme, log-structured NVM system never updates data items in-place. Instead of fixing a home location
for every data item (e.g. virtual pages or objects), log-structured checkpointing designs rely on a mapping table
to relocate newly updated data items to the end of the log. Updated content of data items are also appended to the 
end of the log since NVM favors sequential writes. The problem with log-structured NVM design, however, is that they
penalize every memory access, adding a non-constant overhead to memory operations that access the NVM. In addition,
log-structured designs require an extra garbage collection mechanism, which copies data around and frees stale items
that have been deleted or overwritten, consuming both the bandwidth and cycles. The third problem of log-structured
designs is that they generally require more NVM space than needed, due to the multiversioning nature of the log.

Dual page checkpointing (DPC) attempts to solve all the above problems using a simple mapping scheme built into the memory
controller. Instead of generating log entries and forcing complicated write ordering of log entries, DPC never performs 
in-place updates to older data items (i.e. created by previous epoches) during an epoch. Compared with coarse-grained 
COW, DPC uses bit vectors to maintain dirty and location information, such that pages can actually be managed in a flexible,
per-cache line manner. Compared with log-structured NVM, DPC restricts the possible locations a virtual page can be mapped 
to (similar to page coloring, but the restriction is even more strong), and hence can just use one bit to indicate the 
location of a virtual page. Put them all together, DPC can achieve fast hardware checkpointing with small metadata and 
torage overhead.