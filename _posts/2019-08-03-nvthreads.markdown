---
layout: paper-summary
title:  "NVthreads: Practical Persistence for Multi-threaded Applications"
date:   2019-08-03 00:16:00 -0500
categories: paper
paper_title: "NVthreads: Practical Persistence for Multi-threaded Applications"
paper_link: https://dl.acm.org/citation.cfm?doid=3064176.3064204
paper_keyword: NVM; Critical Section; Redo Logging
paper_year: EuroSys 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper introduces NVthreads, a parallel programming framework aiming at providing persistency without burdening 
programmers with modifying existing code to fit into the new paradigm, while being efficient on Non-Volatile devices.
Prior to NVthreads, several NVM frameworks have been proposed. As pointed out by this paper, these proposals are usually 
not user-friendly and/or inefficient for two reasons. First, programmers may be forced to adapt to a new programming
paradigm that is partially or entirely different from what they are used to. This may involve some deep learning curve,
or require changing existing source code. Second, most prior publications focus on utilizing the byte-addressibility
of NVM devices, which implies tracking and persisting changes at the unit of cache line sized blocks (64 Bytes). Although
this scheme sometimes have less storage overhead, the extra cost of persisting every cache line may outweigh the 
storage benefit, and makes the system under-perform. 

NVthreads seeks to solve the above two problems using atomic region inference and page-level redo logging. NVthreads assume 
that programs directly run on an address space mapped to the NVM (i.e. there is no address backed by DRAM, such that all 
cache line evictions will be directed to the NVM device). NVthreads also assume that programmers use the pthread library
for thread synchronization. Notably, this paper assumes programmers will use pthread_lock/unlock and pthread_wait/signal
to implement critical sections and signaling, although other third-party interface can be easily supported. The paper makes 
a critical observation that, if accesses to shared data are always wrapped within a critical section, then shared data 
is always in a consistent state if no thread is in a critical section. The paper therefore concluded that it is sufficient 
to persist modifications to shared data only at the end of a critical section. As long as individual critical sections 
can be rolled back, if the system crashes within a critical section, then after recovery it appears that the critical
section has never been entered, and the system is in a state where no thread is executing a critical section (in fact,
this formalization does not consider local data of each thread as part of the recovery domain; It is simply assumed 
that all local states of the thread are discarded. This makes sense, because after the crash, the application is restarted 
from the main function, and recovery is performed on shared states, at which point previous local states are not used anyway). 
This guarantees that the global shared state is always consistent after recovery, such that computation could proceed
from the interrupted point (in practice, threads can also wrap their local states as a piece of "shared data"; This local
state may record the current process of local computation, which is not shared by other threads, but still needs to be 
preserved during a crash).

NVthreads is implemented with Operating System support of Copy-on-Write (COW). NVthreads instruments the thread library,
such that whenever a new thread is to be started, it re-routes the function call to the "clone" system call. Instead of 
creating a new thread with shared address space with the parent thread, the clone() system call will create a new process
with its own page table and page access permissions. The newly created process has all its user pages marked as read-only.
Normal read accessed are not affected. When a store instruction attempts to update a page, a page fault will be raised 
by the process, which is handled by the handler of NVthreads. The page fault handler allocates a physical page from the DRAM
as the local buffer for dirty data, adds the page address into its write set hash table, and then remaps the virtual 
address to be accessed to the new physical page. All future updates on this page will not trigger any page fault, and 
can proceed at full processor speed. Compared with cache line granularity design in which all store operations are 
instrumented and will generate a log entry, the page-level design has a clear advantage that it has less instrumentation 
as well as logging overhead. At the end of the critical section, NVthreads "commits" the critical section by generating 
redo log entries, and then updating the shared state. First, it iterates over dirty pages in its write set hash table, 
and compares the content of the dirty page with the original shared page. Differences will be recorded in redo log entries
at byte granularity (to save logging storage). The redo log entries are then flushed to the NVM logging area after all pages have
been processed. NVthreads then writes an committed mark at the end of the log to indicate to the recovery manager that the 
critical section has been fully persisted, and then executes a persistence barrier. The barrier will stall the processor until
all previous writes have been persisted on the NVM. After that, NVthreads updates the shared page by copying redo entries
to the shared pages. Note that, to avoid data race, the changes must be copies back at byte granularity, because otherwise
two threads updating a page concurrently may collide with each other, and some updates may be lost. 

After a crash, the recovery manager scans the log to locate all valid log entries that have successfully committed (i.e. have 
the committed mark). It then reapplies these log entries in the order they are generated by different threads (the paper does not 
mention how a global ordering of log entries is enforced, or there is no global ordering). After applying all valid log entries,
the rest are discarded, and recovery completes. The program is restarted from the beginning. The programmer is responsible
to check whether the current instance of the program is a restarted process after recovery, or it is just a new process.
In the former case, the programmer should call some special routine to perform after-recovery tasks such as rebuilding 
their own thread-local states, and then resume execution from the recovery point. 

Special handling is also needed to properly persist nested critical sections. There are two cases of nested critical sections:
fully (perfectly) nested and partially nested (e.g. 2PL-style locking protocol). The general rule is that any two overlapping 
critical sections on the same thread should be flattened or merged into one, because otherwise, depending on the 
access pattern of data in two critical sections, it is possible that one of them is rolled back, and the other happens to 
have accessed modified data and committed. In this case, the final state is no longer consistent, because the state 
after recovery contains a variable whose value is derived from nowhere. The same rule also applies to critical sections on 
different threads that are communicated via a condition variable (CV). To avoid data inconsistency, the paper proposes 
using global reference counting. Every time a page is duplicated for COW, the counter for the original page is incremented
by one, and the current owner is recorded in the page metadata (e.g. a hash table); The opposite is done when a critical
section commits. When a critical section first accesses a page, it checks whether the page is already dirty (i.e. ref count
non-zero), and if true, it means that the current critical section may read states updated by another active critical
section, and hence, the former can only commit after the latter, since the recovery process will either recover both, or 
only recovery the latter, which is correct. To achieve this, a commit dependency is created from the current critical section
to existing critical sections that have a reference to the page. The current critical section must wait until all these 
dependencies are resolved (i.e. critical sections are committed), after which it can commit.
