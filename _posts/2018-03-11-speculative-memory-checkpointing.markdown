---
layout: paper-summary
title:  "Speculative Memory Checkpointing"
date:   2019-03-11 02:38:00 -0500
categories: paper
paper_title: "Speculative Memory Checkpointing"
paper_link: http://2015.middleware-conference.org/conference-program/
paper_keyword: Checkpointing
paper_year: Middleware 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Speculative Memory Checkpointing (SMC), which is an optimization to the classical incremental memory 
checkpointing technique using Operating System supported Copy-on-Write (COW). In the classical undo-based scheme, the 
checkpointing library relies on virtual memory protection and OS page table to detect whether a write operation is conducted 
on a certain page. Program execution is divided into consecutive epoches, which is the basic unit of recovery. During each 
epoch, the library tracks pages modified by the application, and copies the undo image to a logging area for recovery. 
Programmers use library primitives to denote epoch boundaries and restoration operations. On restoration, the library just
walks the undo log in reverse chronilogical order, and applies undo images to corresponding page frames, until the target 
epoch to restore to has been reached. To track the list of modified pages during every epoch, at the beginning of the epoch,
the library requests the OS to mark all pages in the current process as non-writable. Page faults will be triggered when
the user application writes a page for the first time, during the handling of which the undo image is copied to the 
logging area. The page is marked as writable (if it is writable without checkpointing) after the page fault handler returns,
such that following page writes within the same epoch do not trigger logging.

This paper identifies the problem with page fault driven checkpointing: efficiency. The paper shows by measurement that 
the cost of handling page faults can be significantly larger than simply copying a page or computing a page checksum. 
In fact, page copy only takes ~500 cycles, while COW takes more than 4000 cycles, an eight times overhead. Based on this
observation, the paper proses a speculation scheme for estimating the set of pages that might be copied during the next
epoch, called the Writable Working Set (WWS), at the beginning of every epoch. Instead of copy-on-demand as in COW, the 
checkpointing library copies these pages optimistically at the beginning of the epoch, and unsets the write protection bits
for them. Any following write operations on these pages do not incur overhead of page faults, and hence can improve overall
performance. Note that the estimation scheme does not need to be perfectly accurate. Slightly overestimating the working set
may result in unnecessary copies, but as the measurement suggests, these redundant page copies actually do not pose a 
significant problem compared with using page fault handler for every page write. Correctness is also guaranteed, because 
in the case of overedtimation the undo image is identical to the memory image when the epoch ends.

The paper proposes three ways of estimating the WWS of an epoch at the beginning of the epoch. The first two algorithms 
are based on active lists, which are just lists of page IDs. Initially, all pages are marked as non-writable. The active 
list is built during the first few epoches by adding every page for which the page fault is triggered. All pages in the 
list are considered as hot pages, and will be copies at the beginning of an epoch. The two algorithms, Active-RND and 
Active-CKS, differ in how pages are removed from the list. In Active-RND, there is an upper bound on the number of pages 
in the list. If in some epoch a page is to be added, but the list is full, then the algorithm will randomly select a page
from the list and then remove it. The paper claims that randomly selecting a page performs better than some other algorithms
such as LRU, CLOCK or FIFO. In Active-CKS, no upper bound is put on the list size. Instead, a page is removed from the 
list if the checksum of the page has not changed in the last N epoches. The paper recommends using N = 5. Computing the 
checksum for a page is also inexpensive according to the measurement, which only takes a few hundred cycles. 