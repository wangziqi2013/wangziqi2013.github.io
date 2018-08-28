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
number (commit mode) or an aligned pointer to the undo log (encounter mode). Every memory location in the transaction domain
needs to be associated with one versioned lock. There are several schemes of mapping from memory locations to version
locks, the most representative of them being "Per-Object" (PO), "Per-Word" (PW) and "Per-Stripe" (PS). PO takes advantage of 
the object header in high-level programming languages such as JAVA. TL benefits from the spatial locality of PO scheme as the lock
word is located right next to the data being accessed. Both PW and PS maps the address of the memory location directly to 
an array of locks. The only difference is that in PS the address is right-shifted before the hash value is computed. For 
unmanaged languages such as C++, in order to balance both performance and safety, it is suggested that commit mode / PS is the 
best combination. In the next paragraph, we default to the commit mode / PS scheme, and postpones the discussion of other 
combinations to later sections.

The lifecycle of TL transactions under commit mode with PS locking is similar to a typical OCC transaction. There are three
phases during the execution of TL transactions: read phase, validation phase, and write phase. During the read phase, 
the transaction maintains a read set and a write set as linked lists. Both sets track addresses of data items. For 
read operations, the value of the lock is loaded before the item is accessed, and saved in the read sets. For write operations, 
the uncommitted new value is buffered in the write set. Special care must be taken if a read operation hits a write set entry.
Instead of accessing shared data item, the read operation should return uncommitted data from the write set. If the lock bit
is set when testing the versioned lock before accessing a data item, the read operation can choose either to spin on the lock
for a bounded number of cycles, or to abort immediately. 

During the validation phase, transactions first acquire locks for all items in the write set. As with the case for reading, if the 
lock is already held by another transaction, the current transaction could choose to wait for bounded amount of cycles or to abort. 
After locking the write set, the transaction then proceed to verify the read set by comparing the most up-to-date value of the 
versioned lock with the version maintained in the read set. Should any disagreement occurs, the transaction must abort, because a 
write-after-read conflict has happened, which cannot be easily resolved. If read validation succeeds, then the transaction 
commits by writing uncommitted values in the write set back to shared data items. 