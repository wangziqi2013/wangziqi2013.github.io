---
layout: paper-summary
title:  "What Really Makes Transaction Faster?"
date:   2018-08-27 23:15:00 -0500
categories: paper
paper_title: "What Really Makes Transaction Faster?"
paper_link: http://people.csail.mit.edu/shanir/publications/TRANSACT06.pdf
paper_keyword: TL; STM
paper_year: TRANSACT 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Transactional Locking (TL), a Software Transactional Memory (STM)
design that features low latancy and high scalability. Prior to TL, researchers have proposed
several designs that address different issues. Trade-offs must be made regarding latency,
scalability, ease of programming, progress guarantee, and complexity. Compared with previous
designs, TL highlights certain design choices which give it an advantage over previous STM
proposals. First, TL allows data items to be accessed without introducing extra levels of
indirection. Compared with DSTM where each transactionally accessed object must be marked with
a special ownership record, fewer cache misses and lower memory latency in average is expected.
Second, TL adopts a blocking approach by introducing lightweight spin locks during the 
commit protocol. While admitting the possibility of execssive waiting due to blocking on 
write locks, it is argued that, in practice, write locking does not cause significant slowdown 
with a combination of bounded waiting and retry mechanism with exponential backoff. Third, instead of 
locking data items for in-place update as they are to be written during the read phase as in some STM designs,
TL buffers uncommitted writes in transaction local storage. Data items are not locked until commit time
when uncommitted modifications are made public after validating the read set. The OCC style read-validate-commit
lifecycle of transactions greatly improves the throughput of the system when contention is large.
Finally, by relaxing the progress guarantee, TL is considerably less complicated compared with other 
wait-free STM designs. The reduction in complexity directly translates into increased throughput and decreased
latency.

TL runs two modes, a commit mode, where data items are write locked only before commit, and an encounter mode where 
locks are placed as early as when items are updated. Both modes leverage versioned locks as a way of detecting
read-write and write-write conflicts. A versioned lock is a machine word that can be atomically read, written, and CAS'ed. 
It consists of two parts: a one bit field which is used as a spin lock, and the rest of the word as either a version
number (commit mode) or an aligned pointer to the undo log (encounter mode).