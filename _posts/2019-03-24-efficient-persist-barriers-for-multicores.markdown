---
layout: paper-summary
title:  "Efficient Persist Barriers for Multicores"
date:   2019-03-24 21:00:00 -0500
categories: paper
paper_title: "Efficient Persist Barriers for Multicores"
paper_link: http://homepages.inf.ed.ac.uk/vnagaraj/papers/micro2015.pdf
paper_keyword: NVM; persist barrier; persistency model
paper_year: MICRO 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a new implementation of persist barrier, a common programming language construct for NVM programming. 
Prior works have proposed four persistency models of different semantics and constraints. The first and the most straightfirward
persitency model is strict persistency, in which the order that memory operations persist must follow the order that they
become visible. In other words, the persistency model follows the consistency model. To achieve this, processors must
not make store operations visible to other processors via coherence before these operations are persisted to the NVM, which 
essentially make the cache write-through. This model suffers from performance issues for three reasons. The first reason is that
writes must propagate through the entire cache hierarchy which usually consists of several levels, since the processor 
bypasses the cache hierarchy and directly writes into the NVM. The second reason is that NVM writes are typically much slower
than a local cache write. The latency of store operations is longer even compared with uncached memory writes. The last reason
is that since the pipeline must not reorder persistent stores with other stores, there is little chance that NVM writes 
can be coalesced or batched in order to take advantage of the internal scheduling of the memory controller. The second model is 
epoch persistency, which relaxes strict persistency by allowing store operations to be persisted in a different order than
the one they become visible. A special memory ordering primitive called the epoch barriers are inserted into the instruction 
stream. It is required that store operations before the barrier must be persisted before any store operations after the 
barrier. The easiest implementation of epoch persistency is to track dirty cache lines accessed within an epoch. At the end 
of the epoch, these dirty cache lines are forced to be written back to the NVM using special instructions such as clwb.
Regular store barriers may also need to be inserted to enforce correct ordering between epoches. The processor in the meantime
must stall and wait for the persistence to complete before continue executing the next barrier.