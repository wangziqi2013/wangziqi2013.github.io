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

