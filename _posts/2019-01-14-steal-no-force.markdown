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
cache set overflows, the transaction must not proceed.