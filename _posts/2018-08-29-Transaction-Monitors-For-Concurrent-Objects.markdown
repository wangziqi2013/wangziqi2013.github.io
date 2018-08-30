---
layout: paper-summary
title:  "Transaction Monitors for Concurrent Objects"
date:   2018-08-29 23:11:00 -0500
categories: paper
paper_title: "Transaction Monitors for Concurrent Objects"
paper_link: https://link.springer.com/chapter/10.1007/978-3-540-24851-4_24
paper_keyword: OCC; STM; Monitor
paper_year: ECOOP 2004
rw_set: Bloom filter
htm_cd: Lazy
htm_cr: Lazy
version_mgmt: JAVA Object
---

Monitor has long been a classical programming construct that is used for mutual exclusion. The code segment surrounded
by a monitor, called a "critical section", is guaranteed by the compiler and language runtime to execute as if it were 
atomic. In practice, monitors are mostly implemented using a mutex. Threads entering the monitor acquire the mutex, before 
they are allowed to proceed executing the critical section. The mutex is released before threads exit the monitor.
Simple as it is, using a mutex to implement monitor is not always the best option. Three problems may arise when
threads acquire and release mutexes on entering and exiting the monitor. First, on modern multicore architectures, both 
acquiring and spinning on a mutex induce cache coherence traffic, which can easily saturate the communication network and 
thus delay normal processing of memory requests, causing system-wide performance degradation. Second, if multiple threads
wish to access the critical section concurrently, only one of them would succeed acquiring the mutex, while the rest has 
to wait until the first one exits. The blocking nature of a mutex can easily become a performance bottleneck as all threads
are serialized at the point they enter the monitor. The last problem with mutexes is that threads are serialized unnecessarily
even if they do not conflict with each other, which is the usual case for some workloads. If threads are allowed to proceed
in parallel, higher throughput is attainable while the result can still be correct.

This paper proposes transactional monitors, which is a novel way of implementing a monitor. A transactional monitor does not 
prevent multiple threads from entering the monitor. Instead, the read and write operations inside the monitor are instrumented 
with the so called "barriers". Barriers are invoked on every read and every write operation performed by threads. They keep 
track of information that is used to determine whether a certain thread has seen a consistent snapshot later on when the 
thread is about to leave the monitor. This process, by its nature, must be optimistic, which means that every thread executes
under the assumption that objects it accesses will remain in the state observed when it enters the monitor. If the assumption
fails to hold because another thread has modified one of the objects the current thread has read, the thread must not commit, 
and should retry executing the critical section.

The algorithm used by transactional monitor resembles Optimistic Concurrency Control (OCC) with backward validation, or BOCC. 
In BOCC, a transaction's lifecycle is divided into three phases: read phase, validation phase, and write phase. In the read
phase, the thread only reads from shared state (or uncommitted data if available), while write operations are buffered in 
thread local storage. Not publishing uncommitted writes to the shared state ensures safety property because uncommitted state
will not be accessed by other transactions. During the validation phase, the transaction checks its read set against the write 
set of transactions that: (1) committed before it does; and (2) committed after it starts. The set of transactions for backward
validation are identified using a commit ID, which is drawn from a global version counter. Threads enter a critical section
before they start to validate, and exits the section after they increment the version counter and tag their write sets with the 
counter. On transaction begin, a begin timestamp is read from the version counter. Validating threads only need to validate 
against transactions whose commit ID is between their begin timestamps and the current value of the timestamp. If the intersection
between the read set of the validation transaction and the write set of all concurrent transactions is empty, then validation
succeeds, as the transaction is known to have read a consistent snapshot of the shared state, which is taken by the time the 
transaction begins. The write phase simply flushes all uncommitted data to shared state, and hence commits the transaction. 

Transactional monitor uses a variant of BOCC which is described below. There are two modes of operation: A low contention mode,
which is intended for cases where most threads are read-only; and a high contention mode, which allows writers to execute concurrently.
The runtime system should switch between these two modes based on the degree of contention, though it is not mentioned in the paper 
how this is achieved. In the low contention mode, the monitor object maintains an atomic descriptor, which consists of two fields:
A thread identifier field which stores the identity of the writer (or set to null if non-existent), and a counter which keeps 
track of the total number of threads in the monitor. These two fields, as suggested by the name, should be able to be read and 
written atomically. When a thread enters the monitor, it checks whether the writer field is set. If yes, then the thread spins 
on the descriptor until the writer leaves the monitor. Otherwise, the thread enters the monitor after incrementing the counter. 
This guarantees that whenever a writer thread is active in the monitor, no new thread could enter, thus avoiding conflicts between 
the writer and the new thread. For threads already in the monitor, read barrier needs no further action except returning the value 
from the shared state. Write barriers, however, tests the atomic descriptor in the monitor object, and sets the writer field to 
itself if the field not already set. This can usually be done with a Compare-And-Swap (CAS). If the CAS fails, then another 
thread has successfully acquired exclusive right to perform write, and the current thread must abort and retry. If the CAS
succeeds, then the current thread becomes the exclusive writer, and subsequent writes of the same thread are always committed
to the shared state. One invariant this algorithm demonstrates is that, after a thread has acquired write permission, the number 
of threads in the monitor can only decrease, assuming that threads only stay in the monitor for a finite amount of time. 
The writer field will not be cleared until the last thread leaves the monitor, serving as a flag for other read-only threads. 
When threads are about to exit the monitor, they check the writer field. If the writer field is not null, which indicates that some
thread has written to some data items during the current thread's execution, the current thread must abort and retry. Otherwise,
the current thread decrements the thread counter atomically, and exits from the monitor. As mentioned above, since the number of
threads can only decrease after a thread has acquired permission to write, it is expected that when the last thread leaves the 
monitor, it can observe a thread count of one. In this case, the thread also clears the writer field by storing null into it, 
thus unblocking all threads waiting to enter the monitor. 

The biggest advantage of the low contention mode is that no extra metadata is required to keep track of the read and write 
sets of threads. Instead, the writing thread is assumed to conflict with all reading threads. In the cases when writes are 
rare, this scheme works because for most of the time, it will only be readers performing non-conflicting operations. If,
however, write operations occur quite often, then the monitor should switch to high contention mode, in which a finer grained 
conflict detection scheme is used.

