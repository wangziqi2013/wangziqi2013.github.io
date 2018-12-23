---
layout: paper-summary
title:  "Transactional Collection Classes"
date:   2018-12-21 18:25:00 -0500
categories: paper
paper_title: "Transactional Collection Classes"
paper_link: https://dl.acm.org/citation.cfm?id=1229441
paper_keyword: Concurrency Control; MVCC; OCC; Interval-Based CC
paper_year: PPoPP 2007
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes semantic concurrency control, a technique that reduces transactional conflicts on data structures when
they are wrapped in long transactions. With transactional memory, it is temping to implement data structure operations using 
transactions. When the data structure is used in larger transactions for extra atomicity (e.g. multiple operations on the 
data structure are expected to complete as an atomic unit), then it is inevitable that the transaction used to implement 
data structure operations will be nested with the parent transaction. 