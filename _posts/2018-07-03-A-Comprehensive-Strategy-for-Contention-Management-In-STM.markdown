---
layout: paper-summary
title:  "A Comprehensive Strategy for Contention Management in Software Transactional Memory"
date:   2018-07-03 21:12:00 -0500
categories: paper
paper_title: "A Comprehensive Strategy for Contention Management in Software Transactional Memory"
paper_link: https://dl.acm.org/citation.cfm?id=1504199
paper_keyword: STM; TL2; Contention Management
paper_year: PPoPP 2009
rw_set: Lock Table for Read; Hash Table with Vector for Write
htm_cd: Lazy
htm_cr: Lazy
version_mgmt: Hybrid
---

This paper proposes a contention management system that supports Software Transactional Memory with lazy acquire
and lazy version management. The system features not only a generally better contention management strategy, but
also enhances the base line STM with useful capabilities such as programmer-specified priority, irrevocable transaction,
conditional waiting, automatic priority elevation, and so on. 