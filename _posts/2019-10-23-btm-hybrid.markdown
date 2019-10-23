---
layout: paper-summary
title:  "Using Hardware Memory Protection to Build a High-Performance, Strongly-Atomic Hybrid Transactional Memory"
date:   2019-10-23 12:10:00 -0500
categories: paper
paper_title: "Using Hardware Memory Protection to Build a High-Performance, Strongly-Atomic Hybrid Transactional Memory"
paper_link: https://dl.acm.org/citation.cfm?id=1382132
paper_keyword: BTM; UFO; Hybrid TM; HTM; STM
paper_year: ISCA 2008
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a hybrid transactional memory that provides both fast hardware transaction and strong semantics. 
The paper points out that neither HTM nor STM is feasible for real-life software development at the time of writing, because
HTM transactions are either bounded or have to pay extra cost to support unboundedness, while STM suffers from high
instrumentation and metadata overhead. Hybrid TM, as a seemingly suitable middle ground solution, can support both
fast HTM transaction and comprehensive and unbounded STM transaction, but designing one is still challenging. First,
hybrid TM often requires that the hardware check conflicts with software transactions. This hardware checking can be 
time consuming and complicated to implement, while conflicts only happen for a small fraction of the accesses. Second,
many hybrid TM could not handle mixed transactional and non-transactional code in a strongly atomic manner. Non-transactional
accesses may incur unintuitive behavior, for example, when the hybrid transaction aborts and tries to roll back. 

The hybrid TM proposed by this paper is based on three distinct components: A best-effort hardware transactional memory,
BTM; a software TM that replies on compiler instrumentation, and the hardware memory protection mechanism that glues 
the HTM and STM together under the same conflict domain. In the following paragraphs we briefly introduce all these three 
components.

The hardware TM component, BTM, is similar to a best-effort HTM implemented in the L1 cache with lazy version management
and eager conflict detection. Two extra bits, TR and TW, are added to the L1 tag array to indicate whether the cache line
has been accessed by a transactional load or store instruction. Conflicts are detected via cache coherence in the same way 
as Intel TSX. No I/O, exceptions or interrupts are allowed during the execution of a transaction, which result in an immediate
abort. On transactional conflicts, the hardware compares the age of the two conflicting transaction, and the younger one
is aborted. If a transaction is aborted, the abort reason and the address related to the abort (if any) will be stored in
a pair of transactional status registers. The control flow is then transferred to an abort handler which will read the abort
status and make appropriate decisions (retry or fall back to software).