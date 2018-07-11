---
layout: paper-summary
title:  "Fast Serializable Multi-Version Concurrency Control for Main-Memory Database Systems"
date:   2018-07-09 23:58:00 -0500
categories: paper
paper_title: "Fast Serializable Multi-Version Concurrency Control for Main-Memory Database Systems"
paper_link: https://dl.acm.org/citation.cfm?doid=2723372.2749436
paper_keyword: MVCC; Hyper
paper_year: SIGMOD 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Multiversion Concurrency Control (MVCC) has been widely deployed with commercial databases such as PostgreSQL,
OracleDB and SQL Server. In practice, MVCC is favored by commercial database vendors over other concurrency control schemes 
such as Optimistic Concurrency Control (OCC) and Two-Phase Locking (2PL) for the following reasons. First, compared with
2PL, transactions running MVCC do not wait for other transactions to finish if conflict occurs. Instead, for read-write 
conflicts, transactions are able to time travel and locate an older version of the data item, while the resolution of 
write-write conflicts can be optionally postponed to commit time. Allowing multiple conflicting transactions to run in
parallel greatly increases the degree of paralellism of the system, and on today's multicore platform this feature prevents
processors from being putting into idle state frequently. 