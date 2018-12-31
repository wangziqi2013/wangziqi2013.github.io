---
layout: paper-summary
title:  "Interval Based Memory Reclamation"
date:   2018-12-28 22:07:00 -0500
categories: paper
paper_title: "Interval Based Memory Reclamation"
paper_link: https://dl.acm.org/citation.cfm?doid=3178487.3178488
paper_keyword: TLB Shootdown
paper_year: ASPLOS 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Interval-Based Memory Reclamation (IBR) as a way of performing Garbage Collection (GC) in 
lock-free data structures. In a lock-free data structure, since readers usually do not synchronize with writers, 
if a writer thread removes a block accessible via a pointer, it is possible that one or more readers still
have a reference to that block, and hence the actual reclamation of the block should be delayed. To ensure safe access
of memory blocks for readers, the GC scheme should guarantee that a block is only removed after it has been unlinked
from the data structure and the number of thread holding a reference to it drops to zero. 

Many GC schemes were proposed before IBR. Reference counting is among one of the earliest GC schemes ever proposed. 
It works in a straightforward manner: When a reader thread accesses a block using a pointer, it increments a reference 
counter for that block atomically. Note that since the block may have just been reclaimed before the reader thread has a 
chance to increment the counter (i.e. reader reads the pointer, another writer sneaks in, unlinkes the block, checks its 
reference counter which is zero, and then reclaims the memory of the block), the reference counter should not be embedded 
within the block. An independent data structure is needed to maintain reference counters for all blocks. When a block is 
to be deleted, the thread unlinked the block, and checks the reference counter. If the value is zero, then the node can be 
reclaimed. The pointer value should also be validated by re-reading the pointer field from the parent block, because otherwise 
it is possible that the block is unlinked and reclaimed before the reference counter is incremented. This issue is common 
in GC algorithms if the protection of a pointer is only applied when the pointer is first used to access the block.
Although RC is easy to understand and simple to implement, its extra overhead of having to write global states even for 
read operations is a performance bottleneck. For example, in a concurrent binary tree implementation, any operation
on the tree must contend for the cache line that stores the reference counter for the root node. 

Hazard Pointer (HP) is another technique that optimizes out unnecessary memory contention incurred by RC. Instead of 
writing to global states when a block is accessed, in HP, threads only publish their local read set to a thread-local
lock-free list. When a block is unlinked, its address must be checked against all thread-local lists to see whether 
it is part of the working set of any other thread. If this is true, then the reclamation of the block is delayed until
no thread holds a "hazard pointer" to this block. Similar to RC, since the protection of a block is only applied right 
before the thread accesses the block, it is possible that the block has been unlinked and reclaimed before the 
hazard pointer is observed by other threads. To prevent this, threads must re-validate the value of the pointer 
field after adding the hazard pointer and issuing a memory fence to make sure no unlink operation has been done 
before the HP is added. After the thread completes an operation, it should also releases all hazard pointers from 
the thread-local list. 

Epoch-based reclamation (EBR) further improves HP in two aspects. First, threads never declare individual pointers 
as hazardous, which requires at least two extra operations per pointer accessed by the thread (one before usage 
and one after). This improves not only performance but also the usability of the GC algorithm, since programmers
can just write their programs without realizing the existance of GC. In addition, threads never validate a pointer
after declaring it as hazardous by re-reading the pointer field. Instead, at the beginning of every operation, threads
declare a new epoch which protects all pointers accessed within and after the epoch. No operation needs to be done when
a pointer is used to accessed the block, as the pointer has been protected since the beginning of the operation. 
The details of EBR is described as follows. The algorithm maintains a centralized epoch counter, which is periodically
incremented to make progress. Each thread has a thread-local epoch counter and garbage list which holds unlinked 
blocks. Thread-local counters are initialized to +&infin;. At the beginning of every operation, threads read the 
global epoch into the local epoch. When they unlink a block, the block is linked to the local garbage list. 
The delete epoch of the block is also stored in the garbage node. During garbage collection, the GC thread first computes 
the minimum epoch among all local epoch counters. Then the garbage list of each thread is scanned, and blocks whose 
delete epoch is smaller than the minimum epoch computed in the previous stage is reclaimed. When a thread completes 
its operation, it sets the local epoch back to +&infin; such that it never blocks the reclamation of any block.

EBR does not have strong progress guarantee if a thread is blocked or killed in the middle of an operation. In this 
case, the local epoch counter will never be reset, and hence GC cannot progress past the epoch when the thread
enters the current operation. The essence of the problem is that EBR reserves epoches too conservatively: At the 
beginning of an operation, all epoches from the current epoch to +&infin; are reserved by reading the global epoch
into its local epoch counter. This condition can be relaxed by adding an upper bound to each thread, representing the 
maximum epoch the thread reserves. The interval between low epoch and high epoch prevents all blocks deleted within 
this interval from being reclaimed.

Prior to IBR, people have proposed Hazard Eras (HE) which addresses the problem of epoch reservation being too 
conservative in EBR. In HE, not only the epoch an object was born, but an epoch the object was created, are recorded. 
The object header is extended with two fields: The created epoch, and the deleted epoch. This can be done conveniently
with C++ and constructor semantics. Threads declare the current global epoch using a local epoch list whenever it 
dereferences a pointer. Note that since this is similar to HP which only applies protection to a pointer before 
it is dereferenced, the pointer should be validated after the current epoch is declared. The epoch list is cleared 
at the beginning and end of each operation. The reclamation works as follows: When a thread performs GC, it scans 
the local garbage list as in EBR. For each garbage node in the list, it checks whether for every thread, there is a 
declared epoch between its created and deleted epoch. If this is true, then potentially that thread can hold a 
reference to the pointer, and hence the reclamation should be delayed. Otherwise the block can be reclaimed immediately.
With HE, if a thread is stalled due to I/O or killed halfway inside an operation, the number of blocks that cannot be 
reclaimed is bounded, since the thread is no longer able to make any reservation.

IBR borrows the idea of created and deleted epoch from HE, while using an interval to represent reserved epoches. By
tagging objects with created epoches, the GC algorithm is able to bound the number of unclaimable blocks even if 
a thread fails to make progress. By using an interval rather than individual epoches to represent the reservation,
a better interface can be used which does not force the programmer to "unreserve" blocks when they leave 
the working set. IBR works as follows: When a new object is created, its created epoch is read from the current global 
epoch counter, and stored in the object header. When an object is deleted, the epoch counter is read as the deleted
epoch which is also stored in the header. Threads have two local epoches: One lower epoch and one upper epoch.
At the beginning of the operations, both are set to the current global epoch. Let us assume for a while that it is 
always legal to access the object header at any moment (in reality this might cause undefined behavior if the header 
is accessed after the object is reclaimed). The reservation process is as follows: Whenever a thread accesses 