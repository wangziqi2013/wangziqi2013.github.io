---
layout: paper-summary
title:  "Transactional Mutex Locks"
date:   2018-03-24 16:31:00 -0500
categories: paper
paper_title: "Transactional Mutex Locks"
paper_link: https://www.cs.rochester.edu/u/scott/papers/2010_EuroPar_TML.pdf
paper_keyword: TML; Transactional Mutex Lock; OCC; ORec
paper_year: 2010
rw_set: Single ORec
htm_cd: Eager; Optimistic Incremental
htm_cr: Eager
version_mgmt: Eager
---

This short paper proposes a lightweight STM, Transactional Mutex Lock (TML), that has extremely low metadata and 
instrumentation overheads. Although TML may not demonstrate state-of-the-art performance, its simple implementation
and low overhead make it an ideal building block for larger transactional systems. For example, programming 
languages can use TML to implement features that support more complex STM mechanisms such as abort and roll back.
Furthermore, hardware transactional memory can leverage TML as a simple fall-back path for transactions that are 
unable to be handled by the hardware. Experiments show that TML performs reasonably well compared with simple mutex
and read/write locks, given its simple design and low metadata overhead.

Instead of using fine grained metadata for OCC validation, TML treats the entire shared state as a single variable,
and hence only uses one global counter as the sequence lock to protect it. On transaction start, the global sequence 
lock is sampled and stored in the local variable (can be either TLS or compiler allocated stack variable). 
Optionally, transactions are not allowed to start if the global counter's value is odd as a writer is executing. On 
transactional read, the data item is first loaded, and then transactions check the current global counter against its 
local copy. If the value differs, then a interleaving write operation must have been (will be) conducted on some data item.
This is treated as a potential conflict, and reader transactions must abort. On transactional write, the writing transaction
first attempts to acquire the global writer lock by using CAS to update its value. The writing thread uses its local copy
of the global counter as CAS's old value, and the local copy plus one as the new value. If CAS fails, then there is another
writer trying to acquire the global writer lock and has succeeded, in which case the writer aborts. If CAS succeeds,
the writer lock is acquired. From now on, other transactions neither can run concurrently with the writing transaction,
nor can they be spawned. The writer thread executes to the commit point. On commit, it increment the global counter,
making it even, and concurrent reader or writer threads can start running again.