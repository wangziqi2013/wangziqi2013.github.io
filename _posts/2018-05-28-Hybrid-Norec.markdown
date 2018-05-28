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
counter serves two purposes. First, it acts as a global write lock to all data items, serializing
the write phase of all committing transactions. Second, the commit counter also signals all 
reading transactions that a commit has taken place/is being processed. The read set of the 
transaction should be validated using value validation