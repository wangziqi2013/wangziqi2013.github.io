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
an epoch barrier. One possible implementation of the epoch barrier consists of a cache ling flush, a memory fence, a pcommit
instruction, and another memory fence. On newer hardware the pcommit and the second memory fence may be unnecessary because
cache line flush itself is sufficient to guarantee the durability of writes when the instruction returns. After the epoch 
barrier returns, the log manager then writes the LSN of the entry, which is followed by the second epoch barrier. On recovery,
if a log entry's LSN does not match its actual offset in the log file, the recovery manager then believes that the log 
entry is corrupted by the failure, and will discard it. 