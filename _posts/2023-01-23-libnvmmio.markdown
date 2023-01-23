---
layout: paper-summary
title:  "Libnvmmio: Reconstructing Software IO Path with Failure-Atomic Memory-Mapped Interface"
date:   2023-01-23 00:03:00 -0500
categories: paper
paper_title: "Libnvmmio: Reconstructing Software IO Path with Failure-Atomic Memory-Mapped Interface"
paper_link: https://www.usenix.org/conference/atc20/presentation/choi
paper_keyword: NVM; Libnvmmio; File System
paper_year: USENIX ATC 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents libnvmmio, a user-space file system extension to support efficient failure-atomic semantics 
on Byte-Addressable Non-Volatile Memory (NVM). Libnvmmio acts as an intermediate module between the user space system 
call interface and the existing memory-mapped file interface. Libnvmmio lowers the software overhead of the legacy 
read/write interface and implements an epoch-based persistent model that allows dirty data to be persisted in an
orderly manner.

Libnvmmio was motivated by two issues with the existing NVM-based file systems. First, as NVM offers low-latency
I/O that is comparable to those of DRAM and is much faster than SSD and HDD, the software overhead of the 
file system stack has become a major problem that lies on the critical path of file access. In particular,
the paper points out that the legacy read/write file access interface incurs large overheads due to data copies
between the kernel buffer and user-space buffer. The paper also conducted experiments that showed that data copies
between buffers constitute almost half of the total execution time. 
By contrast, memory-mapped I/O using the mmap interface enables low overhead file access as the virtual-to-physical 
mapping is only set up once by the OS kernel on the first access to a page and the rest is handled by the hardware MMU. 
Second, programs that use NVM file systems often need a property called failure atomicity, which guarantees that a 
file operation is atomic concerning system failures. In order to support this property, programmers used to 
implement their own persistence primitives such as the persist barrier consisting of cache line flushes followed 
by a memory fence. However, ad-hoc solutions to persistence are error-prone and, in most cases, suboptimal.
Prior works have proposed two techniques that guarantee failure atomicity. The first is shadow paging, which buffers 
file updates with shadow pages and commits the updates by atomically updating the pointers in the indirection level
of the file system. The paper commented that shadow paging incurs large write amplification since it must be done at
the page level and will cause cascaded updates on the indirection level. The second technique is logging, with
either undo or redo logging being a viable option. However, neither of the two logging approaches is tuned for 
all cases. For example, undo logging is beneficial in write-dominant scenarios as it does not require extra indirection
into the log on read accesses, while redo logging works the best in read-dominant scenarios.

Libnvmmio addresses both issues of the existing file systems which we present as follows. 
Overall, libnvmmio acts as an intermediate level between the user space program and the underlying file system 
interfaces. Libnvmmio does not implement any low-level file system operations such as metadata maintenance but instead
simply serves as a system call translation layer and delegates these low-level operations to an existing NVM file 
system. In particular, libnvmmio, during the runtime, intercepts file systems calls open, read, and write and 
replaces them with memory-mapped systems calls. On file open, it translates the open system call to mmap which 
maps the file into the virtual address space and returns the file descriptor. Per-file metadata is also allocated
on a persistent heap. Libnvmmio also maintains an internal mapping that associates the file descriptor as well
as the virtual address range allocated to the opened file with the per-file metadata.
On file reads and writes, libnvmmio translates the operations to the corresponding load and store sequences 
on the virtual address space of the mapped file. Extra log entries may also be generated to support failure atomicity
(which we cover later). 
If the user application already explicitly maps the file using mmap, libnvmmio also provides the corresponding
interface, `nvmemcpy`, for accessing memory regions mapped to a file as a replacement for regular loads and stores. 
In this case, the application needs to be modified and recompiled in order to benefit from libnvmmio.
None of these operations will invoke system calls, nor do they require the heavyweight 
file system stack. As a result, libnvmmio can be implemented entirely in the user space and it effectively 
reduces the cost of system calls and the file system stack.

To address the second problem in prior works, namely providing epoch-based persistence with low overhead, libnvmmio
leverages both undo and redo logging and switch between them dynamically in the runtime. 
Libnvmmio maintains log entries for every 4KB block in the file (except the last block which can be of arbitrary size). 
In order to find the log entry with low overhead, Libnvmmio maintains an internal radix tree in the per-file
metadata that maps block offset into the file to the corresponding log entry. 
Log entries are generated at small granularity by file write operations. Each log entry consists of a 
starting offset within the block, the length of the write, and the payload (which can be either undo or redo data).
For undo logging, libnvmmio copies the original data before the write from the offset into the log entry, 
persists the entry, and performs the write in-place. For redo logging, libnvmmio simply copies data to be written 
into the log entry and persists it. 
One additional level of indirection is added to read operations if redo logging is used,
since redo logging stores the most up-to-date data in the log entry. In this case, libnvmmio will check the 
log entry to see if the requested range overlaps with any of the entries and returns data from the log if positive. 

Libnvmmio implements an epoch-based persistence model, where data generated from an epoch will be guaranteed to
persist before data from all future epochs is. Application programs delimit epoch boundaries using the msync()
or fsync() system calls which are also intercepted by libnvmmio.
On receiving the call, libnvmmio advances the current epoch by atomically incrementing an epoch counter in the 
per-file metadata which indicates the current epoch of the file. The global epoch counter is also copied to 
every log entry to indicate the epoch that the log entry belongs to.
After incrementing the epoch counter, libnvmmio will then wake up a background thread dedicated to persistence.
The background thread will then scan the log entries of the file and commit the log entries in the background.
For undo logging, the background thread flushes dirty data back to the NVM for every address range being written.
For redo logging, the background thread updates the file in-place using data from redo log entries.
After the log entries are processed, the background thread removes the entries, and the epoch has been successfully 
committed. Furthermore, if a pending write operation conflicts with an outstanding epoch commit, libnvmmio 
will prioritize
the epoch commit (to avoid race condition) by eagerly committing the log entry first, deleting it, only after
which the new log entry is generated.
