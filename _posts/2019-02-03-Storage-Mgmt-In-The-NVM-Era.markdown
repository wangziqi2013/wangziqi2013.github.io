---
layout: paper-summary
title:  "Storage Management in the NVRAM Era"
date:   2019-02-03 18:41:00 -0500
categories: paper
paper_title: "Storage Management in the NVRAM Era"
paper_link: https://dl.acm.org/citation.cfm?id=2732231
paper_keyword: ARIES; Recovery; Logging; NVM; Group Commit
paper_year: VLDB 2013
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---  

This paper seeks to get rid of centralized logging in classical database recovery schemes such as WAL and ARIES which is 
also based on WAL. The classical WAL is designed specifically for disk-like devices that feature a block interface 
with slow random I/O, but faster sequential I/O. One of the examples is ARIES, where a software-controlled buffer pool 
is used to provide fast random read and write access to disk pages. The buffer pool must observe the WAL property in order 
to guarantee that transactions can always be undone after a crash. In addition, ARIES maintains a centralized log object 
to which all transactions append their log entries. Every log entry has an unique identifier called a Log Sequence Number (LSN).
The log object supports the "flush" operation, which writes back all log entries before a given LSN to the disk. The 
flush operation is usually called when a page is to be evicted from the buffer pool, and when a transaction has completed 
execution and is about to commit. In the former case, the log is flushed upto the LSN of the most recent log entry
that wrote the page, while in the latter case, all log entries written by the committing transaction (and hence all log 
entries with smaller LSN) should be written back.

The combination of software buffering and centralized WAL is well-suited for disk I/O. While accesses to data pages are 
typically slow due to its random nature, the slowness can be compensated by the software controlled buffer pool. On the 
other hand, flushing log records to the disk only involves sequential disk I/O, which in most cases should also be fast.

With the advant of NVM, however, the paper suggests that people should rethink about the design of ARIES and even more 
broadly, Write-Ahead Logging, to identify the new challenges of providing durability to transactions. For example, 
commercial NVM usually provides a byte-addressable interface to users, and can be connected to the memory bus which enables
the device to be mapped directly to the virtual address space such that processors can access individual words directly.
This capability allows the application to dierctly update data items on the NVM without using a buffer pool. Furthermore,
the NVM access timing is different from disk drives. Typical NVM read latency are close to the read latency of DRAM. NVM
writes are much slower compared with reads, but sequential writes can be made fast. With NVM at hand, the paper identifies 
three places in current database designs that can be optimized. First, the background logging and buffer pool manager threads
can be removed, because with fast write access (compared with disks) the database system can update data in-place whenever
they are modificed by the processor. Second, in WAL, the page whose log entries are being written back must be latched to
prevent race conditions. This interferes with normal execution of transactions when contention is high. The last point is 
that WAL can be greatly simplified or even removed with NVM. This saves processor cycles and reduces the latency on the 
critical path. 

The paper then proposes two primitives for performing atomic NVM writes to both log entries and data pages. The motivation 
of atomic writes is that, NVM device, like most memory devices, only guarantees atomicity of writes (and persist requests) 
on word granularity. If a log entry write operation consists of multiple words (which is almost always the case), there is 
a risk that when power failure occurs, some log entries are not properly written. In file system researches this anomaly
is called "torn writes", and is usually addressed by appending a checksum to the log entry after they have been flushed to
the disk. The first primitive, "persist_wal", uses a similar technique, in which the LSN is used instead of the checksum.
When a multi-word log entey is to be written, the log manager first writes the log entry body to the NVM, and then executes 
an epoch barrier. One possible implementation of the epoch barrier consists of a cache line flush, a memory fence, a pcommit
instruction, and another memory fence. On newer hardware the pcommit and the second memory fence may be unnecessary because
cache line flush itself is sufficient to guarantee the durability of writes when the instruction returns. After the epoch 
barrier returns, the log manager then writes the LSN of the entry, which is followed by the second epoch barrier. On recovery,
if a log entry's LSN does not match its actual offset in the log file, the recovery manager then believes that the log 
entry is corrupted by the failure, and will discard it. The second atomic primitive, "persist_page", proceeds as follows. The 
log manager first copies the original content of the page on the NVM to a separate log record, and writes that log record
with "persist_wal". Each log record has a "valid" bit to indicate whether the page has successfully reached NVM or not.
The valid bit is initially turned on when the log record is written. Note that this log has nothing to do with ARIES
undo log, although it effectively reverts the page content should power failure occur during the page write.
The page is then written in-place after "persist_wal" returns. Following the successful page write, the log manager 
executes an epoch barrier to ensure durability of the page write, and then clears the valid bit of the log record
to indicate that the undo image has now become obsolete, which is again followed by the final epoch barrier. On recovery, if
a page is found to be corrupted, indicated by the fact that the log entry is present but valid bit is set, then the 
content of the page is reverted. If the log record itself it corrupted, the page is not actually written, and the log is 
simply discarded. 

The first "persist_wal" uses two epoch barriers per call, while the "persist_page" uses four. To reduce the extra overhead 
of executing an epoch barrier which forces the processor to stall on the store queue and the NVM device, multiple log entries 
and pages can be written together as a batch. The paper gave an example of batching with log records, which works as follows.
First, the log manager writes multiple log body into the log, leaving blank their corresponding LSNs, and executes an 
epoch barrier. Then the log manager writes the LSN for each log record, and executes a second epoch barrier. After the 
second epoch barrier returns, all log entries are guaranteed to be persistent.

The paper then proceeds to propose recovery algorithms that optimize WAL for NVM. The first approach, NVM disk
replacement, where the NVM is only exposed as a disk replacement with block based interface, yields poor performance 
mainly because of the software overhead incurred by the centralized log, the buffer pool manager and the file system. 
The second approach uses In-Place Updates to take advantage of the fast write of NVM and to reduce redo logging overhead.
It runs as follows. When the transaction writes to a page, the update is directly applied to a page using "persist_page"
primitive we just introduced. Undo log entries are also persisted to the NVM as the page is persisted. Note that
"persist_page" primitive itself also uses undo logging, we can combine these two, and the actual number of epoch barriers 
is still four per page write. Note that when the page is being persisted to NVM, a latch must be taken on the page to 
avoid other threads accessing the page. Otherwise, it is possible that another transaction reads the page being persisted,
writes a different page, and then commits before the current transaction. If the system crashes before the former transaction
could commit, the recovery manager would be confused, because the latter transaction reads from a transaction that have 
been rolled back. 

The In-Place Update scheme works well on NVM, because it circumvents the expensive software path of performing buffer pool
management and writing redo logs. It is, however, sensitive to NVM write latency, because the epoch barrier is on the 
critical path. To further reduce the number of epoch barriers, the paper proposes the third scheme which is called "NVM
Group Commit". The group commit scheme assumes a shared buffer pool, which only holds dirty pages written by the transaction.
Transactional reads are directly served from the NVM, taking advantage of fast read operations (unless the page being read
is in the dirty pool, in which case dirty data is forwarded to ensure transactions can see their own updates). Compared with
ARIES which uses "steal, no-force" buffer pool management scheme and relies on WAL to provide durability, NVM group commit
uses "no-steal, force" policy which is exactly the opposite of ARIES. Group commit buffer pools are not allowed to write back
pages before commit, and must write back all dirty pages on commit. Each transaction also maintains a transactional-local
undo log in the DRAM. During normal operation, if the transaction requests to abort, then the undo log is used to roll back
dirty pages (note that since the buffer pool is shared across transactions, we could not simply discard dirty pages on 
transaction abort, as the page may also have been written by other transactions). On commit, the transaction manager pushes 
the committing transaction into a pending queue. After the number of pending transactions or the waiting time reach a 
threshold, the transaction manager group commits all transactions in the pending queue as follows. First, all undo log entries
from the pending transactions are collected, and are written into the NVM. Then an epoch barrier is issued to guarantee 
later operations can always be undone if power failure occurs and the data is corrupted. After that, the transaction manager
flushes the shared buffer pool to overwrite existing data on the NVM. This step is not atomic, and failures could occur
during this process. If it is the case, then the recovery manager scans the log, and will find active entries which indicate
that some pages are not written. Another epoch barrier is issued after writing all pages. Finally, the transaction manager 
clears the valid bits in the undo log entries written earlier, meaning that all transactions have committed successfully
and no rollback would ever happen after this point. Compared with In-Place Update scheme, group commit relieves the critical
path of transaction execution of frequent epoch barriers, which only occurs at the end of transaction, and happens in 
the granularity of batches, further amortizing the overhead.

Two problems still remain to be solved with group commit. The first problem is with long transactions, where one long 
running transaction (e.g. reading analytical transaction) blocks the commit of other completed transactions. If this is 
detected, the long running transaction joins the next batch, while all others are allowed to commit. Since dirty pages 
of the long running transaction is also written back to the NVM in the previous batch, it is then required that those
undo log entries of the long running transaction must not be invalidated after the group commit of the previous batch.
Instead, the undo log of the long running transaction is merged into the next batch, and if the transaction aborts, 
all modifications that are persisted with the previous batch must be explicitly undone on the NVM. The second problem
is buffer pool overflow, which happens when most transactions are write dominant or the buffer pool size is too small.
In this case, we allow all transactions in the current batch to partially commit by running the commit protocol
immediately as described above, and move all transactions into the next batch. Similar to the long running transaction
case, all transactions are treated as a long running transaction, and their log entries from the previous batch
must not be invalidated. On recovery, if the recovery manager detects that some transactions have more than one batch,
the recovery manager will undo their modifications explicitly on the NVM using undo log entries from the corresponding batches.