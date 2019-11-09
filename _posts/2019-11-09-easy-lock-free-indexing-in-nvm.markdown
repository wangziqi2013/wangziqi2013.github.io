---
layout: paper-summary
title:  "Easy Lock-Free Indexing in Non-Volatile Memory"
date:   2019-11-09 17:33:00 -0500
categories: paper
paper_title: "Easy Lock-Free Indexing in Non-Volatile Memory"
paper_link: https://icde2018.org/index.php/program/research-track/long-papers/
paper_keyword: MWCAS; NVM
paper_year: ICDE 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents PMWCAS, a programming primitive featuring both multiword atomicity and durability for constructing 
persistent and lock-free data structures. This paper lists a few advantages of using PMWCAS as the building block for
data structures compared with ad-hoc mechanisms specialized for certain programming paradigms. First, MWCAS simplifies
parallel data structure design and preogramming due to its strong semantics. With MWCAS, arbitraty number of words can 
be compared and swapped in an atomic manner, which greatly benefits pointer-based data structures, in which a single
operation typically involves changing several pointers and fields at different locations. Conventional lock-free programming
using single word CAS must guarantee that each CAS transforms the data structure into a valid intermediate state, and that 
threads must "help-along" on these intermediate states to ensure progress and proper synchronization. Second, MWCAS unifies
atomicity and persistency into the same framework. The descriptor-based implementation of MWCAS provides both atomicity
and persistency, while in ad-hoc data structures, thread synchronization and persistence are often implemented by two distinct 
mechanisms. The third reason is that MVCAS does not rely on specialized recovery and memory reclamation procedures to work.
The programmer can simply wrap any multi-word atomic operation with MWCAS library, and recovery is handled automically after 
crash. For memory reclamation, MWCAS implements its own epoch-based reclamation policy which delays the deallocation of 
memory blocks until all threads have dropped their references to the block. This epoch-based mechanism is integrated
into MWCAS both as its internal memory reclamation policy, and also exposed to users for better code reuse. The authors
also compared their software MWCAS with HTM. The conclusion is that HTM performs slightly better than MWCAS in performance,
but its unstability (no progress guarantee due to spurious aborts) and lack of persistence support make MWCAS a better choice
in general.