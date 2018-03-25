---
layout: paper-summary
title:  "NOrec: Streamlining STM by Abolishing Ownership Records"
date:   2018-03-24 18:34:00 -0500
categories: paper
paper_title: "NOrec: Streamlining STM by Abolishing Ownership Records"
paper_link: https://dl.acm.org/citation.cfm?id=1693464
paper_keyword: NOrec; STM; OCC
paper_year: 2010
rw_set: Log
htm_cd: Incremental Validation
htm_cr: Abort on Validation Failure
version_mgmt: Lazy
---

This paper proposes NORec, which is a refined version of Transactional Mutex Lock (TML). Sharing the same set of 
features with TML, NOrec also does not require piece-wise metadata for each data item. Instead of using merely the 
global counter's value to detect whether concurrent writers exist, NOrec also performs value validation to refine
conflict detection and to avoid false positives.

Compared with TML which updates data items in-place, NOrec's read write pattern is closer to OCC. Its execution is divided 
into three phases, like OCC execution: read, validation and write. In the read phase, all writes to shared items are buffered.
Read operations are instrumented to perform incremental validation. Read-only transactions do not have a separate validation
phase. In an updating transaction's validation phase, a critical section is entered by incrementing the global timestamp counter.
Although not expressed explicitly in the paper, validation and write phases are always synchronized. In the write phase,
dirty values are written back. No new transactions are allowed to begin when another transaction is in the write phase.

Two novel designs distinguish NOrec from the classical timestamp-based BOCC algorithm. The first is value-based validation,
which requires no metadata associated with data items, and can avoid some timestamp related problems such as non-atomic 
write phase. The second is the global timestamp counter representing the current status of the writer. A committing 
transaction notifies all other transactions of its status using the global timestamp counter by incrementing it. Upon 
seeing an odd value of the global counter, new transactions are disallowed to begin to avoid reading the partial commit. 
Transactions sample the value of the counter at the beginning and saves it to a transactionally local variable. On every read 
operation, the current value of the counter is compared with the local value. If these two differ, then value-based validation
is invoked. The validation code first waits for the counter to become even to avoid starting on a partial committed state. 
It then samples the counter, performs the validation, and then compares the sampled counter to the current counter. If 
these two differs, then validation is re-run. 

As we can easily see, the validation uses TML to detect concurrent writers. If the global counter changes, then a writer 
must have committed during the value validation. In this case, a write that changes the read set may be missed, so 
validation must restart. We can also think of the validation routine as a "mini read-only transaction" implemented using 
TML.

