---
layout: paper-summary
title:  "Multi-Version Concurrency via Timestamp Range Conflict Management"
date:   2018-12-20 16:53:00 -0500
categories: paper
paper_title: "Multi-Version Concurrency via Timestamp Range Conflict Management"
paper_link: https://ieeexplore.ieee.org/document/6228127
paper_keyword: Concurrency Control; MVCC; OCC; Interval-Based CC
paper_year: ICDE 2012
rw_set: Software
htm_cd: N/A
htm_cr: N/A
version_mgmt: N/A
---

This paper presents Transaction Conflict Manager (TCM), a MVCC transaction processing engine from Microsoft. 
Instead of utilizing multiversioning and only providing Snapshot Isolation (SI), this paper combines multiversioning 
with Optimistic Concurrency Control (OCC), and provides full serializability support. Compared with Two-Phase Locking (2PL), 
this approach allows higher degrees of parallelism, because transactions are allowed to proceed in parallel even if they conflict. 
The conflict is resolved eagerly as in 2PL, but blocking is not always required. Compared with traditional OCC, TCM 
suffers less aborts, because OCC does not tolerate any Write-After-Read (WAR) conflict on running transactions, such that
if WAR is detected no matter if it can be resolved, the transaction must be aborted. In contrast, TCM performs more detailed 
analysis using timestamps and the nature of conflicts, and hence allows more transactions to commit given the same workload
and scheduling compared with OCC.