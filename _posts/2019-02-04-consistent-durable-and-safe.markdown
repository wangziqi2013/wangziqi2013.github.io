---
layout: paper-summary
title:  "Consistent, Durable, and Safe Memory Management for Byte-Addressable Non-Volatile Main Memory"
date:   2019-02-04 18:20:00 -0500
categories: paper
paper_title: "Consistent, Durable, and Safe Memory Management for Byte-Addressable Non-Volatile Main Memory"
paper_link: https://dl.acm.org/citation.cfm?doid=2524211.2524216
paper_keyword: NVM; Malloc; B+Tree
paper_year: TRIOS 2013
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---  

This paper aims at building a flexible and versatile library for applications to work with the incoming NVM devices.
NVM, due to its special performance and physical characteristics, requires new methodology for tasks such as 
storage management, access permissions, consistency model, and so on. Compared with disks, NVM devices are directly
connected to the memory bus, and hence can be accessed by ordinary load and store instructions, at cache-line granularity.
Accesses to NVM are directly backed by the processor cache, which has hardware controlled cache management policy.
In contrast, disks are mostly accessed with block transfers, which is backed by an operating system controlled 
software buffer cache. Compared with DRAM, NVM features slightly slower reads and much slower writes. In addition, 
execssive writes to the same physical location may cause NVM to wear out and become incapable to record data reliably. 
To avoid this from happening, most NVM devices are equipped with firmware that maintains an internal mapping, which maps 
write operations on the same logical address to different locations, minimizing wear. As a result, algorithm for NVM 
should be designed in such a way that data overwriting is minimum.

Existing libraries and system calls such as malloc, mprotect, etc, are not designed to fit into the NVM paradigm. To
be specific, we assume that NVM is installed into one of the memory slots of the host machine, and can be addressed
as part of the physical address space. The operating system maintains information about the NVM address space. Users
request a chunk of memory mapped to NVM using mmap() system call. The returned virtual address can then be used to
directly operate on the NVM. NVM memory regions are by default cachable to improve read and write throughput. Memory
protection on NVM area are achieved by existing virtual memory protection mechanism. Under these assumptions, libraries
running on NVM should satisfy the following requirements. First, they should reduce memory overwrite as much as possible 
to protect the NVM device from wearing out too quickly. On existing library implementations such as glibc malloc, however, 
the opposite will happen. To improve locality of reference, glibc internally divide memory chunks into different 
size classes, and each size class is maintained as a linked list with pointers stored within the memory chunk. Memory
chunks are poped from and pushed into the linked list in LIFO order for good locality, because chunks that are freed
recently are more likely to be allocated in the future. In addition, on every memory allocation and free, the pointer
and metadata fields in the header and footer will be modified, which increases the probability that certain addresses are 
more prone to wearing. The second requirement is that NVM libraries should be design in a way such that the chance of 
memory corruption by accidental writes (e.g. buffer overflow, off-by-one error, etc.) is minimized. This is because unlike
DRAM, data stored in NVM can survive reboots. If critical data structure is maintained in the NVM, and these data structures 
are corrupted by user programs, it would be hard or even impossible to recover, causing permanent data loss or memory leak.
The third requirement is that protection mechanism on NVM must be lightweight and fast. The paper claims that NVM 
applications rely heavily on VM protection mechanism to avoid data corruption. In current distribution of Linux, this is 
done by calling the mprotect system call. This, however, can incur the overhead of one system call, which is expensive.
The design goal is that a lightweight mechanism is provided such that we do not have to pay extra overhead on every protection 
related call. As a trade-off, the semantics can be relaxed a little. The last requirement is that the library should 
enable applications to query the status of dirty cache lines written to the NVM address space. This capability is necessary
to determine when certain changes have been persisted to the NVM. 

Ths paper then proposes an implementation of malloc, NVMalloc, which satisfies requirement one and two. Requirement one 
implies that blocks should not be allocated in a LIFO order which favors recently freed blocks. As an alternative, the 
NVMalloc maintains a recently freed list of blocks, the "don't allocate list". After a block is freed, it is moved into
the recently freed list. Blocks are only removed from the list in FIFO order after it has spent T seconds in the list.
The paper suggests that T can be 0.2 seconds. By putting an upper bound on allocation frequency of blocks, NVMalloc ensures 
that each block is at most allocated once in every T seconds, which helps wear leveling. The recently freed list 
is organized as a linked list, with pointers and timestamps stored in the block themselves. Note that metadata for blocks 
in the most recent freed list is only modified when a block is pushed into or removed from the list. Metadata induced 
wear should also be minimum, because blocks enter and leave the list only at a limited maximum speed. 

To reduce write amplification, NVMalloc only allocates memory in the unit of cache line sized blocks (64B on most platforms). 
On initialization, the heap is divided into blocks of several pre-chosen size classes. Metadata containing the allocation
state and size of blocks are written into block headers. A checksum is computed based on the size, state, and the relative 
offset of the block (from the heap start address), and also stored in the header. Note that metadata stored in the NVM 
blocks are used as the definite source of allocation information. During normal operation, it might be possible that 
external data structures stored elsewhere may become inconsistent with information stored in the NVM block header. In 
this case, the block header is used to guide allocation decisions, rather than other data structures. On recovery,
the recovery manager scans from the begin address of the heap. It assumes that there might be a valid block header on 
every offset that is the multiple of cache line, and verifies the assumption by computing the checksum. If the computed 
checksum matches the value stored in the checksum field, then a valid block header have been found, and the recovery manager
uses the size of the block to jump to the next header to analyze. 