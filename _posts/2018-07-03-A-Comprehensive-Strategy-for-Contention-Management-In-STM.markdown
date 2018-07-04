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

Contention management is important for both eager and lazy STM designs. The goal of a contention management system is 
to avoid pathologies such as livelock and starvation, while maintaining low overhead and high throughput. Past researches
have mainly focused on policies of resolving conflicts when they are detected during any phase of execution. Among them, the 
Passive policy simply aborts the transaction that cannot proceed due to a locked item or incompatible timestamp; The 
Polite policy, on the other hand, commands transactions to spin for a while before they eventually abort the competitor,
which allows some conflicts to resolve themselves naturally; The Karma policy tracks the number of objects a transaction
has accessed before the conflict, and the one with fewer objects is aborted. This strategy minimizes wasted work locally.
The last is called Greedy, which features both visible read and early conflict detection. Transactions are also assigned
begin times. The transaction with earlier begin time is favored. Also note that due to the adoption of visible reads, the 
Greedy strategy incurs some overhead even if contention does not exist.

None of the above four contention management strategies works particularly well for all workloads and for all STM 
designs. In the paper the baseline is assumed to be a TL2 style, lazy conflict detection and lazy version management
STM. Each transaction is assigned a begin timestamp (bt) from a global timestamp counter before the first operation.
The begin timestamp determines the snapshot that the transaction is able to access, and is also used for validation.
Transactions are assigned commit timetamp (ct) from the same global counter using atomic fetch-and-increment after
a successful validation. Each data item has a write timestamp (wt) that stores the ct of the most recent transaction 
that has written to it, and a lock bit. The wt and the lock bit can be optionally stored together in a machine word. 
On transactional read operation, the wt of the data item is sampled before and after the data item itself is read. 
The read is considered as consistent if the versions in the two samples agree, and none of them is being locked. 
If this is not the case, then the transaction simply aborts, because an on-going commit will overwrite/has already 
overwritten the data item, making the snapshot at bt inconsistent.