---
layout: paper-summary
title:  "Transactional Locking II"
date:   2018-03-18 01:25:00 -0500
categories: paper
paper_title: "Transactional Locking II"
paper_link: http://people.csail.mit.edu/shanir/publications/Transactional_Locking.pdf
paper_keyword: TL2; commit-time lock acquisition; 2PL
paper_year: 2006
rw_set: Linked list in software
htm_cd: Lazy for write; Eager for read
htm_cr: Abort on conflict
version_mgmt: Lazy, Software
---

This paper presents Transactional Locking II, a software TM implementation that
provides transactional semantics to general purpose computation. TL2 solves a few problems
that prior STMs have. First, STM implementations, if not designed carefully, can read
inconsistent states, leading to zombie behavior. Although isolated execution can
prevent zombie transactions from interfering with other transactions, and that zombies will eventually
abort when it fails validation, a special runtime system must be equipped to deal with
unpredictable behavior such as infinite loops of illegal memory accesses. The second problem is
that traditional STM usually assumes a closed memory allocation system. In such a system, transactional 
objects cannot be deallocated or leave transactional state freely, as the GC must guarantee no 
threads could access a deallocated/non-transactional object.

Transactional objects are extended with a versioned spin lock. One bit in the spin lock indicates the lock status,
and the remaining bits store the last modified timestamp. Lock acquisition sets the bit using atomic
CAS, while lock release simply use store instruction to update both the status bit and the version. Versioned locks 
do not necessarily have to be embedded into the object's address range (PO, "per-object" in the paper), as this changes object 
memory layout, and hence renders TL2 algorithm non-portable. Alternatively, the "per-stripe" (PS) locking hashes 
objects' address into an large array of versioned locks. False conflicts can arise due to object aliasing.
In the evaluation section, an array of 1 million 32-bit locks are used.

TL2 observes the OCC read-validate-write (RVW) pattern. Like all STM implementations, read and write instructions 
are instrumented by the compiler to invoke special "barrier" functions. The validation phase performs element-wise
timestamp verification. The write phase observes 2PL for the write set, and updates the per-element timestamp. 
We describe each phase in detail below.

On transaction begin, the value of the global timestamp counter is read as begin timestamp (bt). 
The global counter is not incremented. The transaction uses bt to detect write operations on data items
that are carried out after it starts.

On transactional load, if the address hits the write set, then the dirty value is forwarded. A bloom filter
can be used to reduce the frequency that the write set is searched. Otherwise, 
the barrier adds the address into the read set, and samples the lock status as well as the version. 
The load operation is then performed. After performing load, a post-validation routine checks 
the validity of the read phase up to the current point of execution by examining the current lock status
and version. If the lock is held, then a conflict is detected because another transaction is currently in 
its write phase. If the lock bit is clear, but the version differs from the version in the sampled lock value,
then a transaction must have modified the data item during the load. If versions agree, but they are greater than
than current transaction's bt, then a write must have been carried out before the sampling took place, but after
the read phase starts. Because otherwise, either the timestamps will disagree, or the obtained commit timestamp
is smaller than the bt. In all three cases above, the transaction aborts.

These three cases correspond to the three possible outcome of perfoming a concurrent commit: (1) If the 
commit phase unlocks the data item after the second sampling, then we observe a locked item. (2) If the 
commit phase unlocks the data item between the first and the second sampling, then we observe an
unlocked item with a changed version. (3) If the commit phase starts after transaction begins 
and unlocks the data item before the first sampling, then we observe unlocked and consistent versions, 
but the version is greater than the bt as the commit must have obtained the ct after current transaction starts.
There is risk of reading a value in the committing transaction's write set before it is locked, and then the 
committing transaction locks the write set, causing dependency cycles.

There is actually a fourth case: (4) The commit phase starts before transaction begins, and unlocks the data item
before the first sampling. In this case the read validation does not recognize the potentially overlapping
read and commit phases. The correctness, however, is not affected. This is because the ct of the committing
transaction is obtained after the write has is locked. If ct is less than current bt, then the write set
must have already been locked. In this case, all load operations to the item in the write set before
commit finishes will cause an abort. All values returned by load operations that validate successfully
must thererfore be either not in the write set, or in the write set and is the updated value.

The (1) and (2) above do not require the timestamp to have any ordering property. (1) requires the locked
bit being explicitly visible to reader transactions. (2) requires version numbers to be unique, such that any
commit operation on the item during the two samplings will be reflected by a change in the timestamp.
(3) requires the timestamp to observe some ordering: if the commit phase starts after the transaction begins
in real time, then the commit timestamp must be somehow also larger than the begin timestamp in some ordering. 
In the simple case, we just use a timestamp counter that has the following nice property: if a transaction 
reads the counter before another increment-and-fetch it, then the value obtained by the former must be smaller
than the latter. Both uniqueness and ordering property are satisfied. In later sections we shall see a different 
and more efficient implementation where the ordering between timestamps becomes tricky.

On transactional store, the barrier simply stores the dirty value and address in the write set. 

On commit, the transaction first acquires the lock bit using CAS for each element in the write set.
In this process, deadlock can happen as in 2PL scheme. Either the transaction always lock elements
in an ordered manner, or some deadlock prevention/resolution techniques are applied. Once all locks are 
acquired successfully, the transaction increment-and-fetch the global counter atomically, and 
uses the returned value as the commit timestamp (ct). **Note that the increment of the global counter 
must occur after locking the write set. Otherwise, a reading transaction can fail to recognize 
a conflicting commit**. The read set is then validated again, by checking
the lock status bit and the version. Read validation fails if any read item is locked or the version
is greather than bt. On a successful read validation, the transaction enters write phase, and writes back
dirty values in the write set. Written elements are unlocked by clearing the lock status bit and copying
ct into the version field with a normal store instruction.

The second read validation is necessary, because it prevents non-serializable schedule as shown in the example
below. A dependency cycle can be identified. The first dependency is 1->2 WAR since transaction 2 commits and writes
into data item A. The second dependency is 2->1 WAW since transaction 1 commits on data item A. After the last lock on
the write set is acquired (or in some design, after the validation and write phase critical section is entered), no
transaction could possibly serialize after the current transaction, and hence the validation can be carried out
without races about concurrent write phases, as concurrent write phases can only introduce WAR dependencies.
On the other hand, if transaction 1 does not write A, but write some other data items, then the schedule is 
actually serializable, but the validation protocol still do not allow it, causing a false positive.

**Non-serializable Schedule Example:**
{% highlight C %}
/*
  In this example, we omitted the validation step after locking
  the entire write set.
 */
   Txn 1         Txn 2
Begin @ 100
  Read  A
  Read  B
                Read  C
             (Begin Commit)
                Lock  A
              Commit @ 101
                Write A
               Unlock  A
                Finish
(Begin Commit)
  Lock  A              
Commit @ 102
  Write A
 Unlock  A
  Finish
{% endhighlight %}

One of the advantages of performing post-read validation on every transactional load is that no read 
set validation is required for read-only transactions. Read-only transaction only validates every single read
to make sure every value it accesses is consistent with the begin timestamp. No validation phase or write phase
is ever necessary.

The global timestamp counter is CASed everytime a writer transaction commits. The cache coherence traffic of
the CAS can be reduced by a linear factor by adding the thread ID into the versioned lock. Recall that the
timestamp on each data item must satisfy two properties: (1) Uniqueness. An unlock operation must cause 
the timestamp to change. (2) Ordering. If the commit phase starts after current transaction begin, then the 
unlock operation must write a timestamp larger than the current transaction's bt. (1) can be preserved by each thread
writing its own thread ID and current global timestamp version when unlocking a data item. Reusing the same thread ID and version
combination must be prevented, though. Each thread, therefore, remembers the version part of the last ct, and when it tries
to obtain a new ct, it checks whether its last ct version differs from the current global version. If they are identical,
a new version must be allocated, because otherwise it is possible that the same version is used in the previous commit on
the same data item. The global counter is therefore updated to reflect an incremented version and the committing thread's
ID. (2) is also preserved if reader transactions first check whether thread ID changes in the second sample and bt, and then whether 
the version is greater than the bt. Either of these indicates an overlapping commit phase and hence cause current transaction 
to abort.

To see why (2) is true, imagine the scenario where transaction A begins with timestamp bt and then transaction B locks the write set and 
obtains the ct. B writes into data item x, before A samples x's version and performs the load. 
If B does not CAS a new global timestamp counter, then ct is merely (global.vesion, B.ID), and we know the bt can never be
identical to ct. This is because otherwise B's thread must have updated the global counter to (global.vesion, B.ID) 
in the previous commit, and the previous commit used global.version as the timestamp. This contradicts the assumption.
On the other hand, if B CAS a new global timestamp counter, then the version field increments by 1, which can be detected
by post-validation.

TL2's begin and commit timestamp design can be further optimized by dynamically adjusting the begin timestamp as data items
are accessed. The data-driven dynamic adjustment of the begin timestamp resembles the one used in Tic-Toc, and aims at reducing
false aborts where the abort is caused by artificial ordering violations due to sub-optimal timestamp assignment. To see why this 
helps The canonical TL2 read validation algorithm to reduce abort, think of the case where a data item whose commit timestamp
is greater than the begin timestamp is read. The commit timestamp of the data item will force the reading transaction to
abort, because the begin timestamp defines the "snapshot" that the current transaction hopes to operate on. Reading a more 
recent value generated by a transaction whose commit time is logically greater than the begin timestamp indeed constitutes
a violation. Such violation, however, will not happen if the begin timestamp is greater than the data item's commit timestamp.
Based on the above observation, instead of aborting the transaction on reading a new data item, the optimized TL2 validates 
its read set to make sure they are still value at the current logical time. Then the begin timestamp is adjusted to be the 
current logical time by assigning it to be the value of the global timestamp counter. This is valid, because we know by the 
result of validation that no other transaction could have possibly committed into the read set of the current transaction.
It is therefore correct to consider all its read operations taking place at the current time, although the actual reads 
were performed a few logical ticks ago. Note that during incremental validation, no other transaction could commit, otherwise
the validation should be retries. This is implemented as reading the global counter both before and after validation. If 
the two samples disagree, then some transaction must have committed in-between. The validation function should take care
of this and retry.

Transaction commit could be optimized in a similar way. Since after each successful validation, the begin timestamp of the 
transaction indicates the latest snapshot under which that the read set is valid. Before the transaction is able to validate
and after its read phase, we compare the current begin timestamp with the global timestamp counter. If these two are equal,
then we know no transaction have committed during the last validation and the current time, and therefore the read set of 
the current transaction remains a consistent snapshot. In this case, no commit time validation is needed, because the 
transaction is already known to be consistent. 