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
threads acquire and release mutexes on entering and exiting the monitor. 