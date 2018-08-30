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
thread is about to leave the monitor