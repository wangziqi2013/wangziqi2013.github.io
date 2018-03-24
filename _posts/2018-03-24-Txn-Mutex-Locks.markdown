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