---
layout: paper-summary
title:  "Using Hardware Memory Protection to Build a High-Performance, Strongly-Atomic Hybrid Transactional Memory"
date:   2019-10-23 12:10:00 -0500
categories: paper
paper_title: "Using Hardware Memory Protection to Build a High-Performance, Strongly-Atomic Hybrid Transactional Memory"
paper_link: https://dl.acm.org/citation.cfm?id=1382132
paper_keyword: BTM; UFO; Hybrid TM; HTM; STM
paper_year: ISCA 2008
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a hybrid transactional memory that provides both fast hardware transaction and strong semantics. 
The paper points out that neither HTM nor STM is feasible for real-life software development at the time of writing, because
HTM transactions are either bounded or have to pay extra cost to support unboundedness, while STM suffers from high
instrumentation and metadata overhead. Hybrid TM, as a seemingly suitable middle ground solution, can support both
fast HTM transaction and comprehensive and unbounded STM transaction, but designing one is still challenging. First,
hybrid TM often requires that the hardware check conflicts with software transactions. This hardware checking can be 
time consuming and complicated to implement, while conflicts only happen for a small fraction of the accesses. Second,
many hybrid TM could not handle mixed transactional and non-transactional code in a strongly atomic manner. Non-transactional
accesses may incur unintuitive behavior, for example, when the hybrid transaction aborts and tries to roll back. 

The hybrid TM proposed by this paper is based on three distinct components: A best-effort hardware transactional memory,
BTM; a software TM that replies on compiler instrumentation, and the hardware memory protection mechanism that glues 
the HTM and STM together under the same conflict domain. In the following paragraphs we briefly introduce all these three 
components.

The hardware TM component, BTM, is similar to a best-effort HTM implemented in the L1 cache with lazy version management
and eager conflict detection. Two extra bits, TR and TW, are added to the L1 tag array to indicate whether the cache line
has been accessed by a transactional load or store instruction. Conflicts are detected via cache coherence in the same way 
as Intel TSX. No I/O, exceptions or interrupts are allowed during the execution of a transaction, which result in an immediate
abort. On transactional conflicts, the hardware compares the age of the two conflicting transaction, and the younger one
is aborted. If a transaction is aborted, the abort reason and the address related to the abort (if any) will be stored in
a pair of transactional status registers. The control flow is then transferred to an abort handler which will read the abort
status and make appropriate decisions (retry or fall back to software).

The hardware memory protection, called UFO (User Fault-On), allows user space programs to set permissions to individual
cache lines. In the UFO design, each cache line in the cache hierarchy is extended with two extra bits in the tag array, one 
for read accesses, and another for write accesses. If a memory access hits a cache line, and the corresponding bit is set,
this access will raise an exception, which is then handled by a user-space call back function. The ISA is also extended with 
instructions that set these two permission bits. Furthermore, DRAM pages and disk swap files are also extended to store the two
permission bits when a cache line is evicted from the cache to DRAM, and when a in-memory page is swapped out to the disk,
respectively. The paper suggests that the DRAM bits can either be provided by a dedicated chip, or by the ECC bits. In order
to set permission bits for a cache line, it must be ensured that the line is the only instance of the address in the system
to avoid inconsistencies. To achieve this, the cache controller first acquires exclusive ownership before setting any of the 
bits in the cache tag. This feature has an important implication to the hybrid TM, as we will see below.

The last component, the STM, is described as follows. The STM relies on compiler instrumentation to invoke the read and 
write call back functions before each load and store instruction in the transaction body. The STM also maintains shared
and private metadata. Each transaction has a private transactional working set which records its read and write set in 
a hash set. This working set can be iterated over to enumerate all addresses accessed during the transaction. In addition,
each transaction also has a status word, which can be checked by other transactions as well. An ownership table (otable),
implemented as a chained hash table, stores the ownership records of memory addresses. For every transactional access,
the call back function first hashes the address into one of the hash table buckets, locks the bucket, and then searchs the 
linked list for the address. If the address is not found, it is inserted into the hash table. Otherwise, an existing 
record indicates that the address has been transactionally accessed by another uncommitted transaction, and further actions
are taken based on the type of the record and the current access. If the two accesses are compatible, i.e. read-read, then
the reader transaction will add itself into the list of owners stored in the record, and the read could continue. In addition,
the write bit of UFO is also set, such that hardware transactions accessing the same address can be detected,
which invokes the contention manager on the hardware transaction side (for write accesses, both the read and write bits are set). 
If the two accesses are incompatible, i.e. at least one of the accesses is a write, then conflict resolution is invoked 
to determine which transaction should abort. The aborted transaction iterates over its working set, and unlinks itself 
from all of the ownership records (and delete the record if it is the sole owner). Meanwhile, the surviving transaction 
needs to spin on the status word of the aborted transaction to wait for the abort process to complete before it can resume 
execution. This prevents the conflicting transaction from accessing partially rolled back state. For write accesses, the 
call back function also stores the pre-image of the word accessed in the ownership record. This pre-image is restored to 
the memory location on transaction aborts. For read accesses, only the address is stored. When the transaction is committed, 
all ownership records are removed from the otable as in abort handling, but writes are not undone.

Note that the HTM and STM interacts via UFO memory protection. When STM adds an address into its working set, the correspoinding
bits for the address are also changed. On every access issued by the hardware transaction, the permission bits will be checked
by hardware automatically without incurring any software overhead, and if a conflict truly arises, the hardware transaction
will be notified, and the contention manager will be invoked. The paper also noted that although setting the UFO bits 
requiring exclusive coherence permission on a cache line, which might cause false read-read conflicts (both HTM and STM
reads a word, but STM needs to acquire exclusive ownership of the line), in experiments this effect has been hardly observed, 
the effect of which is hence minimum.