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
global counter's value to detect whether concurrent writes exist, NOrec also performs value validation to refine
conflict detection and to avoid false positives.

Compared with TML which updates data items in-place, NOrec's read write pattern is closer to OCC. Its execution is divided 
into three phases, like OCC execution: read, validation and write. In the read phase, all writes to shared items are buffered.
Read operations are instrumented to perform incremental validation. Read-only transactions do not have a separate validation
phase. In an updating transaction's validation phase, a critical section is entered by incrementing the global timestamp counter.
Although not expressed explicitly in the paper, validation and write phases are always synchronized. In the write phase,
dirty values are written back. No new transactions are allowed to begin when another transaction is in the write phase.

Two novel designs distinguishes NOrec from the classical timestamp-based BOCC algorithm.