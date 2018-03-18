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

TL2 observes the OCC read-validate-write (RVW) pattern. Like all STM implementations, read and write instructions 
are instrumented by the compiler to invoke special "barrier" functions. The validation phase performs element-wise
timestamp verification. The write phase observes 2PL for the write set, and updates the per-element timestamp. 
We describe each phase in detail below.

On transaction begin, the value of the global timestamp counter is read as begin timestamp (bt). 
The global counter is not incremented. The transaction uses bt to detect write operations on data items
after it starts.

On transactional load, if the address hits the write set, then the dirty value is forwarded.