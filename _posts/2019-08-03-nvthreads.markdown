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
as well as logging overhead. 
