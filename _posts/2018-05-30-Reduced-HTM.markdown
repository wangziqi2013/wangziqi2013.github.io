---
layout: paper-summary
title: "Reduced hardware transactions: a new approach to hybrid transactional memory"
date: 2018-05-30 13:05:00 -0500
categories: paper
paper_title: "Reduced hardware transactions: a new approach to hybrid transactional memory"
paper_link: https://dl.acm.org/citation.cfm?id=2486159.2486188
paper_keyword: Reduced HTM; Hybrid TM; TL2; RH1; RH2
paper_year: SPAA 2013
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Hybrid transactional memory can provide the efficiency and parallelism of hardware transactional 
memory by executing the majority of transactions via the hardware path, while maintain the flexibility
of software transactional memory when hardware fails to commit using the slower software based path.
The interoperability between HTM and STM transactions is achieved by designing the algorithm
in a way that both HTM and STM transactions would notify each other of possible conflicts. One
prominent example is Hardware Lock Elision (HLE), where HTM transactions and STM transactions cooperate
to execute a critical section. In HLE, when the hardware executes a lock acquisition instruction, HTM transactions 
speculatively verify that the lock is clear, adding the lock into its read set, and then execute the critical section. 
Any attempts by software fall-back transactions to acquire the lock will abort hardware transactions immediately. 
Multiple hardware transactions can execute in parallel given no data conflict, while the execution of 
HTM and STM transactions must be serialized. HLE may suffer from low degrees of parallelism in some workloads, 
because the serialization of HTM and STM transactions is unnecessary in many cases. This, however, should not
be a major problem, as the majority of transactions in HLE are expected to be executed in hardware mode. 
Only transactions that consistently fail (e.g. because the working sets exceed hardware capacity) will 
use the fall-back path. The latter is relatively infrequent.

In the near future, we may possibly only use HTM for smaller transactions whose size is stable and predictable. 
In the long run, however, the size of transactions executed with HLE might become more heterogenous than 
ever, featuring a mixture of small and large transactions. If this is the case, then the classical method for 
HLE will be overly restrictive, as HTM may observe frequent aborts by STM transactions. 

This paper proposes two hybrid transactional memory algorithms based on TL2. 