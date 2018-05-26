---
layout: paper-summary
title:  "Performance Improvement via Always-Abort HTM"
date:   2018-05-26 00:27:00 -0500
categories: paper
paper_title: "Performance Improvement via Always-Abort HTM"
paper_link: https://ieeexplore.ieee.org/document/8091221/
paper_keyword: HTM; Thread-Level Speculation
paper_year: PACT 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
--- 

Hardware transactional memory can improve the performance of lock-based systems by speculating on
the code path that it has not yet been granted to execute. The speculation has an effect of warming
up the cache and branch predictor, achieving similar effects as hardware prefetching, with significantly
more flexibility. This paper proses an enhanced implementation of TATAS spin lock and ticket lock using 
a variant of current commercial HTM implementations, where the hardware transaction always aborts. Instead 
of having threads spinning on the lock, wasting cycles and introducing coherence traffic, the thread begins 
an always-abort transaction, and performs speculation as if it were executing a hardware transaction. The paper 
claims that by using always-abort speculation, the performance of lock-based systems can be boosted by at most 
2.5 times.

The always-abort hardware transaction memory (AAHTM) design resembles that of Intel TSX. AAHTM_BEGIN starts an
always-abort transaction. AAHTM_ABORT and AAHTM_END both abort the current transaction. AAHTM_TEST checks whether 
the processor is running an always-abort transaction. To distinguish the AA-mode from normal TSX execution, an extra 
bit is added into one of the control registers. AAHTM_TEST tests the flag and stores the result into a register. Other
causes of aborts for TSX, such as cache set overflow, unsupported instructions or exceptions, would abort an AA-transaction
as well. 

The implementation of TAS spin lock takes advantage of AA-HTM as follows. Instead of spinning on the lock variable, the 
worker thread begins an AA-transaction if the lock acquisition fails. The AA-transaction runs the critical section 
speculatively. When the thread compeletes running the critical section, or when the transaction aborts, the thread 
retries acquiring the lock. The same is repeated if lock acquisition fails again. 
