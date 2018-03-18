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

On transactional store, the barrier simply stores the dirty value and address in the write set. 

On commit, the transaction first acquires the lock bit using CAS for each element in the write set.
In this process, deadlock can happen as in 2PL scheme. Either the transaction always lock elements
in an ordered manner, or some deadlock prevention/resolution techniques are applied. Once all locks are 
acquired successfully, the transaction increment-and-fetch the global counter atomically, and 
uses the returned value as the commit timestamp (ct). The read set is then validated again, by checking
the lock status bit and the version. Read validation fails if any read item is locked or the version
is greather than bt. On a successful read validation, the transaction enters write phase, and writes back
dirty values in the write set. Written elements are unlocked by clearing the lock status bit and copying
ct into the version field with a normal store instruction.

One of the advantages of performing post-read validation on every transactional load is that no read 
set validation is required for read-only transactions. Read-only transaction only validates every single read
to make sure every value it accesses is consistent with the begin timestamp. No validation phase or write phase
is ever necessary.