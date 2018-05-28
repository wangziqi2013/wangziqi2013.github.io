---
layout: paper-summary
title: "Hybrid NOrec: a case study in the effectiveness of best effort hardware transactional memory"
date:   2018-05-28 17:19:00 -0500
categories: paper
paper_title: "Hybrid NOrec: a case study in the effectiveness of best effort hardware transactional memory"
paper_link: https://dl.acm.org/citation.cfm?doid=1961296.1950373
paper_keyword: NORec; STM; Hybrid TM
paper_year: ASPLOS 2011
rw_set: Hybrid
htm_cd: Hybrid
htm_cr: Hybrid
version_mgmt: Hybrid
---

Current implementations of commercial hardware transactional memory (HTM) features lazy
version management and eager conflict detection. A transactional store instruction cannot be 
observed by both transactional and non-transactional loads until the writing transaction
commits. In addition, both transactional and non-transactional store to a location in 
a transaction's read set will cause an immediate abort of that reader transaction.

NORec, a lightweight software transactional memory (STM) design, features lazy version management
and incremental lazy conflict detection. A transactional write to data items cannot be observed by 
other STMs until the writing transaction commits. This, however, will cause a hardware transaction
to abort. NORec always maintains a consistent read set by using a commit counter. The commit 
counter serves three purposes. First, it acts as a global write lock to all data items, serializing
the write phase of all committing transactions. Second, the commit counter also signals all 
reading transactions that a commit has taken place/is being processed. The read set of the 
transaction should be validated using value validation when the commit operation finishes. 
This is achieved by transactions taking a snapshot of the commit counter before it starts and 
before every validation. If the value of the commit counter differs from the snapshot after a 
load operation or after a validation, the load or validation must be retried. This ensures that
all read and validation are conducted under a consistent snapshot where no transaction has ever 
committed. The last purpose of the commit counter is to indicate an "unstable" state of the snapshot,
and hence prevent new transactions from beginning. New transactions take a snapshot of the counter,
and if a commit is currently going on, the new transaction will not begin.

The commit counter in NORec is a 64 bit integer consisting of two parts. The lowest bit of the integer 
serves as the "locked" bit. If it is set, then a commit is currently being processed. All remaining bits 
comprise the version counter, which counts the number of commits (excluding the current one if the lowest
bit is set) that have taken place. Committing transactions first set the lock bit to exclude all other 
transactions from committing, performing reads, validating, and beginning. Then it writes back the write 
set. After the write back completes, it clears the locked bit and increments the version counter by one.
The last step is performed using atomic Fetch-and-Add or Compare-and-Swap. In fact, the assignment of bits in 
the commit counter allows both atomic "lock" and "unlock-increment" be carried out by an atomic Fetch-and-Add 
by one.
