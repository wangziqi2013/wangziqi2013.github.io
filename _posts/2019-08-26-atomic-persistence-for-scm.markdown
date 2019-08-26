---
layout: paper-summary
title:  "Atomic Persistence for SCM with a Non-Intrusive Backend Controller"
date:   2019-08-26 02:38:00 -0500
categories: paper
paper_title: "Atomic Persistence for SCM with a Non-Intrusive Backend Controller"
paper_link: https://ieeexplore.ieee.org/abstract/document/7446055
paper_keyword: Logging; NVM; Memory Controller
paper_year: HPCA 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a lightweight method for implementing atomic persistent regions by using redo logging. Traditionally
there are three ways of ensuring atomicity with NVM: undo logging, redo logging, and shadow mapping. Undo logging requires
write ordering between the log entries and dirty cache lines, such that dirty data can never reach NVM before the log
entry does. Enforcing such write ordering is expensive on some architectures, and involves changing the cache hierarchy
directly. Shadow mapping, on the other hand, allows the same address to be mapped to different physical locations using
a mapping table, enabling background persistence of different "layers" or "versions". The mapping table, however, must also
be kept crash-consistent such that the after-crash recovery routine can still access persisted data. Such a change also
involves non-trivial hardware change and run time metadata cost. 

The paper proposes using redo logging to implement atomic persistent transactions. Two problems naturally exist with 
redo logging. First, although redo logging does not require the write ordering between log entries and dirty data 
(since dirty data can always be replayed by applying log entries), dirty data must be kept away from the NVM device
before the transaction is fully committed, because otherwise, there is no way of rolling back these partial changes.
Similarly, the end-of-transaction mark in the redo log must be written before the transaction commits. The second problem
is read redirection into the log every time the cache misses. This happens if the transaction size exceeds the cache 
size and hence some blocks inevitably overflows as a result of capacity miss. These evicted blocks are either discarded 
because their contents are already stored in the log anyway, or they are kept in an L4 cache of the hierarchy, often
implemented as a part-of-DRAM data structure with a mapping table. This mapping does not have to be kept presistent,
because the de facto content of memory after a recovery is recorded in the redo log. On a read cache miss, the bloc must either
be fetched from the log by walking log entries and locating the most recent write, or by querying the in-memory 
mapping table. Such re-direction overhead can be large sometimes, which prevents a load miss from being resolved in
a timely manner.

This paper proposes adding a dedicated victim cache for storing overflowed blocks from the LLC. The victim cache is responsible
for holding cache blocks evicted from the LLC, and at the same time, serving LLC misses. No log entry walking is necessary
with a victim cache. In the rare scenario where the victim cache is not sufficient to hold all dirty blocks, a DRAM backed
mapping table is used to locate the most recent dirty lines. 

This paper assumes a persistent transaction model. Applications are written in a transactional manner such that persistent
stores that must be committed atomically are wrapped by a special code block. During compilation, the code block will be 
translated to two library calls: OpenWrap() and CloseWrap(). Store instructions between the call are translated to 
library call wrapStore(), which generates the log entry in software (without flushing them at once). Each wrap instance
will be allocated an identifier, which will be explained later. The memory controller is extended with a special unit
responsible for persisting transactions. Both OpenWrap() and CloseWrap() will notify the memory controller of the 
beginning and the end of a persistent transaction. The memory controller maintains a list of wrap IDs. A wrap's identifier
is added to (removed from) this list (included in the message sent from the processor) when a wrap begins (commits).
As will be made clear by the text below, this list of wrap IDs help us delete stale entries from the victim cache.
The paper suggests that the list can be implemented as a bit vector on hardware, preferrably one bit per core (since 
we expect each core to run one transaction at a time). 

A log entry is generated when a write operation to the NVM region is performed. Note that since this paper does propose
changing the frontend cache hierarchy, this must be done by software routines. On beginning of a new transaction, in addition
to adding the unique ID into the internal list, the memory controller also allocate a log buffer for the newly started 
transaction. The log buffer is located at a well-known address on the NVM such that the recovery handler can find right
after the post-crash reboot, and the paper suggests that they can be maintained like a linked list. Log entries are only
flushed into the log buffer at the end of the transaction using streaming write instructions. Compared with undo logging
in which dirty blocks are flushed back to NVM on commit point, flushing redo log entries can achieve higher throughput, 
since these writes are on consecutive addresses, and can be coalesced in the store buffer. The CloseWrap() library call 
also writes a end-of-transaction mark after flushing all log entries. 

To keep the home locations of NVM data up-to-date, the memory controller gradually migrates data in the redo log entries 
to their home locations. This process is conducted entirely in the background, and hence does not incur extra cycles
on the processor. Log buffers are added to the "retirement list" after they are committed, the logic ordering of 
which are consistent with the ordering of transaction commit (commits are serialized, though not mentioned by the paper).
The memory controller selects the first entry in the log buffer list, and copies the content of the log entry into the 
address indicated by the entry. A log buffer is removed from the retirement list after it has been fully migrated. In
addition, the ID of the transaction is also removed from the internal ID list.

When a dirty block is evicted from the LLC, we check whether the physical address is in the NVM. If positive, the 
block will be stored into a victim cache, which can be implemented as a highly associative hardware cache.
The entry in the victim cache serves as a temporary source of dirty data when a memory request misses in the LLC.
A block can be discarded by the victim cache after its transaction has been fully migrated. Instead of tagging every
cache line in the hierarchy with the ID of the transaction that writes the block, this paper suggests that we 
only take a snapshot of the internal transaction ID list when the block is evicted. The block can only be removed
when all transactions is this list have been fully migrated. This scheme is correct, because there are two cases:
either the writing transaction is in this list, or not in this list. In the former case, the block will wait for its 
writing transaction to be fully migrated, exactly as specified. In the latter case, it can only be that the writing
transaction has been removed from the list, which implies that it has been fully migrated even before the eviction happens.
In either case, waiting for all transactions to retire ensures correctness. 

