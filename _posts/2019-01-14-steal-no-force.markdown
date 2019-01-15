---
layout: paper-summary
title:  "Steal but No Force: Efficient Hardware Undo+Redo Logging for Persistent Memory Systems"
date:   2019-01-14 16:55:00 -0500
categories: paper
paper_title: "Steal but No Force: Efficient Hardware Undo+Redo Logging for Persistent Memory Systems"
paper_link: https://ieeexplore.ieee.org/document/8327020
paper_keyword: Logging; Durability; NVM
paper_year: HPCA 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a novel technique for performing logging on NVM backed systems that require atomic durability.
Such systems generally employ NVM as a direct replcement for DRAM, where memory reads and writes are issued in the 
same way via the memory controller and are finally served by the NVM connected to the bus using DIMM. In previous works,
two logging schemes are widely used to achieve durability: undo and redo logging. Undo logging saves the before-image 
of the memory location when a modification is about to be applied to the cache line. The before-image is then evicted
back to the NVM for persistence before the dirty line can be evicted. In case of failure, the recovery handler 
reads the undo log from the NVM, and reverts dirty modifications of uncommitted transactions using the before-image.
Redo logging instead saves the after-image of the modification in a separate log (either centralized or per-transaction).
The log is then written back to the NVM for persistency before the transaction can commit. Since no undo information
is saved, dirty cache lines should be held back from eviction until the log reaches the NVM. On recovery, no transaction
should be undone, because modifications must only reside in the cache, and hence will be discarded on power loss. 
The recovery handler traverses the log, discards redo entries of uncommitted transactions (those that lack a commit
record at the very end), and applies modifications in the logical commit order for committed transactions.

Neither undo nor redo logging are ideal for high performance transaction processing with durability requirement.
Undo logging introduces unnecessary write ordering problem: The undo log record must reach the NVM before the actual 
data update, because otherwise if a crash happens between the update and the log write, no recovery can be done. In 
addition, to ensure durability of updates after commit, all dirty lines must be flushed. The flush operation must be 
performed synchronously, which is on the critical path of transaction commit. We call this "force" because cache lines 
are forced back to the NVM on transaction commit. In contrast, redo logging allows faster commit by flushing only log 
records to the NVM and not forcing dirty lines to be flushed. It is, however, necessary to prevent dirty cache lines 
from being evicted to the NVM. The latter may cause problems, because the cache has only limited capacity. If the 
cache set overflows, the transaction must not proceed. One solution adopted by earlier designs is to use a DRAM buffer
as the victim cache. When a cache line is evicted from the processor cache, instead of directly writing them into the NVM,
they are redirected into the DRAM cache which is allocated by the OS and managed as a mapping structure. This way, redo
logging does not impose any constraint on the cache replacement policy, while still being able to perform better than
other schemes. The problem, however, is that extra storage as well as states are maintained by both hardware and software.
The extra design complexity and storage usage might become prohibitively expensive, limiting its usage in actual products.

Using both undo and redo logging in one scheme can solve the problem of each while keeping their benifits. This paper 
assumes the following two properties of the cache: First, cache lines may be evicted from the cache at any time during
the transaction, suggesting that no modifications to the replacement policy is required to implement the scheme. Second, 
on transaction commit, no dirty cache line is flushed. This implies that transaction commit can be a rather quick 
operation since cache line flush is not on the critical path. In database terminologies, these two properties are 
called "steal, no force" which is also assumed by the well-known undo-redo ARIES recovery scheme.

We describe the system and its operation as follows. Transaction bookkeeping and conflict detection are controlled by the 
implementation of the TM, which is off-topic to our discussion. All memory operations within the transaction are treated 
as transactional and persistent. We only consider write operations, because reads naturally do not need any persistency 
guarantee. On every write operation, the cache controller extracts the old and new value. Log records containing both before-image 
and after-image are constructed. Containing both before- and after-image in the log record can double the amount of storage 
required, putting more stress on NVM bandwidth, but have the following benefits. 