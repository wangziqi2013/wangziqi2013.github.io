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
