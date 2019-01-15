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
required, putting more stress on NVM bandwidth, but have the following benefits. First, cache lines can be evicted freely
as defined by the replacement policy. Second, transaction commit can be almost instantaneous, because redo log entries are 
already flushed to the NVM at commit point. Third, on transaction commit, dirty cache lines are no longer needed to be 
flushed to the NVM, because redo logging guarantees persistence. 

One problem, however, remains to be solved: the write ordering problem. In order for undo logging to work, the log entry 
must reach the NVM before dirty update does. In previous solutions, the programmer manually insert a store barrier between 
updating the data and updating the log entry. This condition, however, is overly restrictive, because what we want is really 
just the order that the two updates reach NVM, while what store fences provide is the serialization of commits on the CPU side.
Frequent serialization of instruction commits like this case harms performance, because the processor can no longer reorder and 
coalesce memory operations freely as it is the case with more relaxed memory ordering. This paper relaxes the memory ordering
issue without using fence instructions. Instead, it takes the advantageo of the observation that, in order for an in-place update
to reach the NVM, it must undergo several cache evicts, e.g. from L1 to L2, and then to L3. There is a time window during which
the update written a few moments ago definitely cannot make it to the NVM. This time lower bound is defined by the 
microarchitecture and the memory hierarechy. On the other hand, if proper control is imposed on the timing of log write operations,
we can make strong guarantee that the log record updates always reach NVM before the shortest time in the future it takes 
for an update in L1 cache to propagate to the NVM. Motivated by this, the paper proposes that a dedicated hardware log 
buffer be added to the processor. Log write operations are issued by the processor automatically during execution, and 
hence can be identified and multiplexed into the log buffer. The cache controller then carefully coordinate between cache 
operations and buffer write backs, such that the latter always reach the NVM first. By eliminating the store fence
from the instruction stream, and using a log buffer to perform log writes, normal execution can be parallelized with
log writes in a pipelined manner. Note that log writes must circumvent the cache. On x86 platforms, this is achieved 
using non-temporal streaming write instruction: movntq.

The log is maintained in the NVM as an OS-allocated chunk of persistent memory. System-wise there is only one centralized log
to simplify ordering problems. The processor uses two registers to insert into and remove from the log. The value of registers 
must also be persisted on the log every time they change (the paper does not state how, and if there are multiple processors
in the systen, the consistency of these pointers is also a problem). The log is managed as a circular buffer. On a wrap-around, 
new entries will rewrite old entry. Rewriting log entries of committed transactions will destroy the persistence property, since
there can be dirty cache lines of a committed transaction still in the cache. If the redo log entries of such transactions 
are overwritten, there is no way to recover from a failure since the recovery handler does not know the after-image of the 
cache line. 