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

