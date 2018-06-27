---
layout: paper-summary
title:  "Serializable Isolation for Snapshot Databases"
date:   2018-06-27 01:11:00 -0500
categories: paper
paper_title: "Serializable Isolation for Snapshot Databases"
paper_link: https://dl.acm.org/citation.cfm?doid=1376616.1376690
paper_keyword: MVCC; SSI; Snapshot Isolation
paper_year: SIGMOD 2008
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

Multiversion Concurrency Control (MVCC) is a natural implementation of Snapshot Isolation (SI). Transactions
running under MVCC obtains a begin timestamp (bt) before they issue the first operation. For each read, they 
use the begin timestamp to access the data item with the maximum timestamp among those whose timestamps are 
smaller than the bt. For each write, transactions buffer the update in the local storage. Transactions obtain 
a commit timestamp (ct) from the same timestamp counter at the time of commit, and flushes its local versions, 
which are tagged with ct, to the global version chain. MVCC algorithm that implements SI does not check for 
read-write conflict before commit can take place. Instead, it checks whether two concurrent transactions intend 
to write to the same data item. If this happens, one of the two conflicting transactions must abort. 