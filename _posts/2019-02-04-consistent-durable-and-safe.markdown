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
In addition, permission changes (towards more strict permission) require TLB shootdown to keep the private TLB consistent on
all cores, which itself is a heavyweight event, whose invocation should be minimized as much as possible.
The design goal is that a lightweight mechanism is provided such that we do not have to pay extra overhead on every protection 
related call. As a trade-off, the semantics can be relaxed a little. The last requirement is that the library should 
enable applications to query the status of dirty cache lines written to the NVM address space. This capability is necessary
to determine when certain changes have been persisted to the NVM. 

The paper then proposes an implementation of malloc, NVMalloc, which satisfies requirement one and two. Requirement one 
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

If allocation information were only to be stored at the header of each block, then memory allocation would have to 
iterate through all blocks on the NVM heap to find a block of the requested size, the time complexity of which is 
propotional to the number of objects on the heap. To accelerate this process, NVMalloc also maintains a segregated
free list structure in DRAM as a hint. The segregated free list is similar to the one in ordinary malloc implementations, 
the difference being that nodes in the list do not contain data, but just pointers to the NVM heap. Memory allocation
first checks the segregated list entry of the requested size class. If there is an element in the list, the element will
be popped out, and the routine checks the block header to verify that the list element is consistent with the block
metadata. The reason for inconsistent free list is that when a block merges with the previous or the next block,
NVMalloc does not update the element in the free list for the previous or the next block, leaving the possibility
that some free list elements may have pointers pointing to the middle of a block. To deal with this problem, NVMalloc
also have a bit mask describing global allocation status. A set bit means the corresponding cache line sized block
has been allocated, and cleared bit means it is free. The block header is easily located given a pointer to the middle
of the block. NVMalloc uses both bitmap information and the block header to access the actual block meatdata during
allocation. Note that both the bitmap and the free list can be rebuilt during recovery. They do not need to persist
in any case, and will simply be lost on a failure or reboot.

Storing free list and bitmap in DRAM has another benefit: data corruption is less likely because neither buffer 
overflow nor off-one-one error (and other common mistakes) can corrupt the linked structure. In the case of corrupted
header, they are detected by the checksum field described above. During recovery, if checksum mismatch occurs at the 
location where a block header is expected, the user will be notified of the corruption, and the recovery manager
proceeds by scanning the heap with step size being cache line sized until the next valid header is found.

The next thing the paper proposes is a low overhead memory protection scheme. Memory protection is more important on NVM
because of the way NVM is used by user application. On traditional devices such as disks, an errorneous user program
may only corrupt user data, but not the system's metadata. Such protection capability is provided by carefully coded
validity checking of operations and arguments, as in disk-based file systems and DBMS. On NVM, however, user program
have direct access to the entire NVM address space, in which many critical system metadata is also stored. Restricting 
user program's write access is hence an important part of any usable NVM library.

Calling mprotect on every metadata change is expensive as explained in previous paragraphs. This overhead can be largely
avoided by leveraging the observation that most memory errors are rare (given a non-malicious application), and that the 
protection mechanism does not need to work a hundred percent of the time. As long as the majority of memory errors are 
detected, it will not be long before application developers become aware of the problem, and then work to fix it. 

The new protection mechanism works as follows. Instead of having applications call mprotect and the kernel initiate 
a TLB shootdown for every request, permissions changes are now applied lazily. Application programs write their intents
on changing the permission as messages into a message queue, which is shared between the user space and kernel space.
A kernel thread is scheduled to scan the queue periodically, and takes all elements away from the queue for processing.
The kernel thread performs a stable sort on addresses in the message, and applies the permission changes one by one
in the order that they were pushed into the queue. A stable sort is required, because the order of applying permissions
is important. Note that some permission changes could cancel out. For example, when the application first requests to
raise the permission for a page, and then requests to lower permission for the same page. If these two requests are 
prccessed in the same batch, neither of them would be actually applied. This approach also requires less TLB shootdowns.
Given sufficiently large buffers for holding TLB shootdown information, only one Inter-Processor Interrupt (IPI) is invoked
for every batch.

Special optmization can be applied if the application wishes to lower the permission requirement of a page (i.e. changing 
a read-only page to writable). The application just logs its permission change request in another table shared between the 
application and the kernel, and then optimistically assume that the page is writable. If it is not the case, a page fault
will be triggered when the thread first writes to the page. On receiving the page fault, the kernel will first check
the table to see if any permission change is pending. The permission change request will then be removed from the table
and processed by the kernel. This process is transparent to the application. The permission change appears to become 
effective instantly after the application writes the permission change request into the table. 

The paper addresses the last point (allowing applications to query the state of dirty cache lines) by adding counters and 
version IDs to cache line tags. The design proposal is described as follows. First, an array of counters are added to the 
cache controller. Each counter should be at least 8 bits which allows at most 256 cache lines to be tracked. Counters
can be identified using counter IDs. Each cache line tag is also extended with a field that stores the counter ID.
The cache controller begins counting the number of dirty cache lines upon executing a special instruction, sgroup,
the execution of which allocates a free counter and stores the counter ID into a general purpose register. The application
saves the counter ID as a token to query the counter value. The cache controller also remembers the most recent allocated
counter ID. Whenever a cache line becomes dirty as a result of NVM write, if the counter ID is valid, then the corresponding
counter is incremented. On the other hand, whenever a cache line is evicted or invalidated, the counter is decremented.
The paper did not discuss the behavior of counters on coherence actions, which complicates the design, because some cache 
coherence protocol will write back the dirty line if it is invalidated on one private cache and sent to another as a result
of read shared request. The paper suggests, however, that for inclusive L3 caches, simply adding the counter ID field into
L3 tag array is sufficient. For non-exclusive caches, each core has its own set of counters. The counter ID field should be 
further divided into a local counter ID and a core ID. If a cache line is evicted from the lower level cache to the NVM,
the message should percolate up to the corresponding core, and the counter on the core is decremented. 

Application programmers query the value of a certain counter using the scheck instruction, which returns true if the 
value of the counter is zero. Equipped with sgroup and scheck, programmers no longer need to explicitly issue epoch 
barriers which consists of cache line write backs and memory fence instructions in order to ensure persistence of modifications.
Frequent execution of epoch barriers negatively impacts performance, since it stalls the processor until the write back 
operation completes. This will exclude out-of-order execution that overlaps the epoch barrier with other instructions 
in order to hide latency. Instead of forcing the processor to stall on a write back, with cache line counters, the 
write back can be performed in the background, and the processor just keeps executing instructions. The application,
in the meantime, periodically checks the status of write backs using scheck instruction. This allows better parallelism
in general because of reduced dependency between instructions.

There are still two problems. 