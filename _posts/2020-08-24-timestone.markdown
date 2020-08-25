---
layout: paper-summary
title:  "Durable Transactional Memory Can Scale with TimeStone"
date:   2020-08-24 18:06:00 -0500
categories: paper
paper_title: "Durable Transactional Memory Can Scale with TimeStone"
paper_link: https://dl.acm.org/doi/abs/10.1145/3373376.3378483
paper_keyword: NVM; MVCC; STM; TimeStone; Redo Logging
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents TimeStone, a software transactional memory (STM) framework running on NVM, featuring high scalability 
and low write amplification. The paper points out that existing implementations of NVM data structures demonstrate various
drawbacks.
First, for those implemented as specialized, persistent data structures, their programming model and concurrency model
is often restricted to only single operation being atomic. Composing multiple operations as one atomic unit is most
likely not supported, and difficult to achieve as the internal implementation is hidden from the application developer.
Second, for those implemented as transactional libraries, their implementations lack scalability due to centralized 
mapping structure, metadata, or background algorithms. 
Lastly, conventional logging approach, if adopted, incurs high write amplification, since both log entries and data 
need to be persisted to the NVM.

TimeStone achieves efficiency, scalability, and low write amplification at the same time. TimeStone's design consists 
of two orthogonal aspects. The first aspect is the concurrency control model, which uses Multiversion Concurrency Control 
(MVCC), in which multiple versions of the same logical object may exist to serve reads from different transactions.
MVCC features higher scalability, since only writes will lock the object, while reads just traverse the version chain
to access the consistent snapshot.
Metadata such as locks are maintained in a per-object granularity without any table indirection.
Version numbers are also maintained with each instance of the object copy.
Each logical object may have several copies of different versions stored in NVM and DRAM, forming a version chain from
the most recent to the least recent version.
A global timestamp counter maintains the current logical time as in other MVCC schemes.
On transaction begin, a begin timestamp is acquired, 