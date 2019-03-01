---
layout: paper-summary
title:  "Log-Structured Non-Volatile Main Memory"
date:   2019-02-25 13:20:00 -0500
categories: paper
paper_title: "Log-Structured Non-Volatile Main Memory"
paper_link: https://www.usenix.org/system/files/conference/atc17/atc17-hu.pdf
paper_keyword: Log-Structured; NVM; Durability
paper_year: USENIX ATC 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes log-structured Non-Volatile Main Memory (LSNVMM) as an improvement to more traditional NVMM designs
that use Write-Ahead Logging (WAL). The paper identifies three problems with WAL-based NVM designs. First, WAL doubles the 
number of write operations compared with normal execution. Either undo or redo log entry is generated for every store 
operation, which will then be persisted onto the NVM using persiste barriers or dedicated hardware. In the case where NVM 
bandwidth is the bottleneck, overall performance will be impacted by the extra store operation. The second problem is 
fragmentation, which is a general problem with memory allocators. Commonly used memory allocators such as tcmalloc or glibc 
malloc tend to waste memory when the allocation pattern changes. This problem worsens on NVM, because memory must be utilized
efficiently across applications and even between reboots. In addition, the cost of NVM is still higher than DRAM or disk of
the same capacity, which implies that it would also be economically infeasible to use a general purpose allocator with NVM.
The third problem is that WAL still requires in-place updates to data items on the NVM. If these data items follow the 
ordinary layout a memory allocator usually use, locality can sometimes be bad, which hurts write performance, brings extra 
stress to wear leveling, and also aggravates write amplification.

LSNVMM leverages log-structured design and applies it to byte-addressable NVM, resulting in an NVM system that only appends 
data to the end of log objects. Always appending data to the end of logs has the following benefits. First, since log 
data has a streaming pattern, it can be optimized by both the processor and the persistence controller. In particular,
if the application writes data in large batches, the size of which is a multiple of the size of the row buffer, write 
amplification can be allievated because data does not need to be read and then re-written. Second, in a log-structured
NVM system, only one copy of data is maintained. Both normal access and recovery process use the same data copy, which means
that no redundant data is maintained. The last benefit is reduced fragmentation, both internal and external, because data 
is only appended to the end of the log. Only very few "gaps" is inserted between valid pieces of data. 

There are also several difficulties of implementing LSNVMM. The most prominent problem is that, compared with log-structured
file system or RAMCloud, where data is accessed in object semantics, in byte-addressable NVM, any pointer can be used to
access a piece of memory. The point could be pointing to the head of an allocated memory block, but there is nothing that 
prevents the pointer from pointing to the middle of the block. Simply mapping the starting address of all blocks to its 
relative offset into the log object is insufficient, because the granularity of access is different from the granularity of 
allocation. As we shall see below, instead of using an efficient hash table, LSNVMM chooses a skip list as its main DRAM 
index structure. The second problem is common to all log-structured designs, garbage collection. Since log grows unboundedly,
earlier entries that are freed or overwritten must be deleted from the log, during which process live entries are also migrated
to the head of the log due to partial cleaning of a log chunk. The last problem is how the LSNVMM interface is exposed to
end users. Since NVM provides a more convenient byte addressable interface directed connected to the memory which has close-DRAM
access latency, a traditional file system based interface is infeasible for the software overhead and inflexibility of 
block-based interface.

We next describe the assumptions of LSNVMM. LSNVMM adopts a transactional interface similar to many HTM and STM designs.
Programmers use two compiler provided primitives, xbegin and xend, to start and commit a transaction. Conflict detection
is out of the scope of the paper, but it is suggested that lightweight STMs such as TinySTM can be used to support 
transaction semantics. LSNVMM transactions follow the well-known ACID property: C and I requires that store operations of
any transaction must not be seen by other transactions before the transaction commits. D requires that data 
written by any transaction must not be rolled back after the transaction commits. A requires that either all stores
of the transaction are persisted, or none of them is persisted. LSNVMM also assumes a run-time system which is capable of 
detecting memory allocations and intercepting instructions that access memory. This can be done either using a special purpose 
compiler that instruments every memory allocation and instruction, or with a run-time bianry translation infrastructure.
In either case we will change the actual virtual address that the instruction accesses using a memory mapping table described 
later. In addition, the paper also assumes that the LSNVMM accesses raw NVM device using special OS memory mapping interface.

As stated by the previous paragraph, since there is no fixed home address for data items accessed using their virtual accesses,
a mapping table maps the virtual address of a data item to another virtual address which resides in the memory mapped part 
of NVM. Note that the underlying VA to PA translation is still performed by unmodified paging hardware. By performing the 
translation for every read operation, each time a data item is overwritten, we can just append the updated data to the end 
of the log, and then relocate the data item by remapping the virtual address being updated to the end of the log. The difficulty
here is that data items might be accessed with a pointer that points to the middle of the memory block allocated to it. In
this case, the mapping table should correctly figure out the identity of the allocated block, and update the mapping table
accordingly. To find the starting address of the containing block given any arbitrary unaligned address, the paper proposes
using an ordered skiplist as the main indexing structure. Updates to the skiplist are serialized using a global lock. Read
operations, however, can be performed in a lock-free manner in parallel with update operations. This is because although
a skiplist update involves several atomic steps which require a lock to avoid concurrent update, each of the atomic step
preserves consistency of the skiplist. In other words, reader threads on the skiplist can always find the correct lower bound
given an address as the key while writer threads are atomically inserting elements into linked lists called "towers".
The skiplist based mapping table is maintained in DRAM, and will be lost during a power failure. The recovery handler,
on the other hand, rebuilds the mapping table on recovery by replaying log entries. We describe recovery in later sections.

Each thread in LSNVMM maintains three logs: An allocation log which records memory allocation operations; A deallocation
log which records memory deallocation operations; A main log which stores data written into memory blocks. The first two
logs are only written, but never read during normal operations. They are important, however, to the recovery process.
The recovery handler could restore the state of the memory allocation by replaying the allocation and deallocation logs. 
Based on the same reason, the memory allocator in LSNVMM does not need to be designed for NVM. In fact, the paper suggests 
that an ordinary allocator such as Hoard is sufficient. To simplify garbage collection and transaction management, the global
log object is divided into fixed sized chunks, which is the basic unit of garbage collection. Chunks are further divided into
transactional blocks, which stores the transaction metadata as well as a pair of pointers to other blocks of the same transaction
(in case that one block is not enough for the transaction's write set). These sibling pointers are never read during normal
operation. On recovery, the handler needs to know whether a transaction has committed by finding the latest chunk and 
checking if a commit record has been written.

The normal execution of LSNVMM is described as follows. When the application requests memory allocation within a transactional
region, the allocator only reserves a range of virtual address space without populating it with physical pages. The request is also
recorded in an allocation log, which will be flushed when the transaction commits. Memory free operations are similarly logged 
in the deallocation log. The run-time system should keep a table of speculatively allocated blocks, and allocate a transactional
private buffer to each of the block. Store operations on these blocks will be redirected to the corresponding buffers during the 
transaction. We omit the details of conflict detection here because it is an orthogonal area of research. On transaction 
commit, the commit handler first persists speculative writes by flushing them to the thread's log. The log head pointer 
is incremented by the size of the write set, and then the commit handler copies data in speculative blocks to the log area 
using streaming writes. New entries are inserted into the mapping table, with keys being the starting addresses of blocks 
allocated during the transaction, and values being pointers to the physical address of the corresponding log entry. Similarly,
blocks that are deallocated will be removed from the mapping table. In the last step, the commit handler flushes both the 
allocation log and deallocation log, after which the transaction is declared to be committed, and a commit record is written. 

Like all log-structured systems, LSNVMM requires periodic garbage collection (GC) to recycle storage occupied by stale data.
In LSNVMM, data become stale either because the block they are in is freed and the free operation has committed, or because 
another committed transaction updates the block. In both cases, the entry for the home address in the mapping table will be 
modified to reflect those changes. LSNVMM uses several background threads to perform GC. These GC threads wake up periodically
and check log chunks. As described in the previous section, chunks are basic units of GC. GC threads scan chunks in the log, 
and for every log entry in a chunk, it queries the mapping table and see if the mapping table still has an entry, and if 
the entry still points to the log entry. If either the mapping table entry does not exist or no longer points to the log 
entry, the log entry is known to be stale. A chunk is garbage collected, if the portion of stale entries exceeds a threshold.
The GC thread copies valid data to the end of the log, updates mapping table entries atomically, and eventually frees 
the chunk.

Recovery works in a two-stage manner with multiple threads as follows. In the first stage, all threads collaborate to 
partition log entries from the beginning of the log into buckets basded on their home addresses. This can be done in 
similar to the mapping phase of map-reduce. Then in the second phase recovery threads work locally to rebuild the mapping 
table. Each recovery thread claim one or more buckets, and sorts the log entries using version ID. Note that the version 
ID from TinySTM indicates the logic serialization order of updates. After sorting these log entries, the recovery thread 
finds the most recent version for each address, and inserts that version into the mapping table. Note that malloc and free
operations are also recorded in the log, and hence should also be replayed during this process. Normal execution will 
resume after rebuilding the mapping table.