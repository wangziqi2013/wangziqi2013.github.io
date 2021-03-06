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
Note that if a data item is in both sets, then the lock operation should check not only the lock bit, but also the version number.
If the current version number disagrees with the version number in the read set, the transaction can immediately abort. The atomic 
check is performed using Compare-And-Swap. After locking the write set, the transaction then proceed to verify the read set by 
comparing the most up-to-date value of the versioned lock with the version maintained in the read set. Should any disagreement 
occurs, the transaction must abort, because a write-after-read conflict has happened, which cannot be easily resolved. If read 
validation succeeds, then the transaction commits by writing uncommitted values in the write set back to shared data items. 
Writer locks are released after write back finishes. The transaction increments the version counter by one and stores the new 
version as well as the cleared lock bit into the lock. The store operation does not have to atomic, because the transaction now 
has exclusive access to the locked data item.

In an open memory system, where programmers are allowed to compose transactions using malloc() and free(), the usage of PO
scheme is discouraged. This is because transactions may access invalid lock bits after the object is freed by another transaction.
For example, assume transaction A removes a node from a linked list and frees the node, while transaction B writes into the same node.
A commits before B. When B enters validation phase, it acquires all locks in the write set, including the lock associated with
the node that has already been freed, before it checks the read set and eventually finds out that the node has been deleted and 
then aborts. Programmers in this case should prepare for the possibility and some transaction acquire a lock which is not even
malloc'ed, or, even worse, the piece of memory is re-allocated to another transaction, causing an unexpected "flicker".

Using PS or PW scheme seems to dodge the problem of transactions accessing a piece of memory after another transaction frees it,
as the array of locks resides in a chunk of memory that will never be freed. This, in fact, only addresses part of the problem.
Even with PS or PW scheme, special care must be taken when memory leaves the system by calling free(). In the example above, imagine that
a PS or PW scheme is used instead. Transaction A and B behave exactly as described. We change the interleaving between A and B.
This time, transaction B enters validation first, and it successfully commits. Before B has a chance to write back uncommitted
values, transaction A also commits, and then calls free() on the node. Note that in this case, transaction A and B's read sets 
contain only the pointer that leads to the node, which is not modified by transaction B. In addition, transaction B's write set 
only contains a word inside the node, while transaction A's write set contains the node pointer. Neither A nor B conflicts with
each other. After A commits, however, transaction B resumes execution and writes into a chunk of memory that has been freed,
causing unexpected behavior. Note that in this case, the serialization order does not matter at all, since A is serialized after 
B, given that B accesses the node before A removes it. 

The solution, as suggested by the paper, is to have transaction A waiting for the object to "quiesce" before it can be freed.
An object becomes quiesce when all transactional write locks are released. Transaction A can only free the node after it 
commits once all concurrent transactions that write to the node has committed or aborted. Non-concurrent transactions do not 
have to be considered, because after A commits, the node cannot be accessed anymore. 