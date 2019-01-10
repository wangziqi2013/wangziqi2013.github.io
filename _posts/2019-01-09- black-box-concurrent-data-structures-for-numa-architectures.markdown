---
layout: paper-summary
title:  "Black-Box Concurrent Data Structures for NUMA Architectures"
date:   2019-01-09 17:24:00 -0500
categories: paper
paper_title: "Black-Box Concurrent Data Structures for NUMA Architectures"
paper_link: https://dl.acm.org/citation.cfm?id=3037721
paper_keyword: NUMA; Concurrent Data Structure
paper_year: ASPLOS 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Node Replication (NR), which provides an efficient solution for converting a sequential data structure
to a concurrent version, which is both linearizable NUMA-aware. In NUMA architecture, all processors share the same physical
address space, while the physical memory is distributed on several NUMA nodes. A NUMA node consists of one or more cores and 
a memory module. Memory accesses from a processor have non-uniform latency, depending on the address assignment. Generally
speaking, it is faster for a processor to access memory in the same node (i.e. local memory) than to access memory from 
a different node (i.e. remote memory). If not designed properly, a NUMA-oblivious data structure may suffer from the 
worst case scenario where most memory requests have to be served by a remote memory, which easily tanks performance.

In order for NUMA-aware data structures to perform well, communications across NUMA nodes must be minimized. NR solves the 
issue by replicating K instances of the same data structure on each node, where K is the number of processors, admitting the 
memory inefficiency of (K - 1) times more memory usage. Logically speaking, these K copies all represent the current state of 
the data structure. They are maintained consistent using a shared log. Worker threads only perform updates and reads on their 
local instances. Update operations on one node are propagated to other nodes by adding an entry to the log describing the 
change that has to be made. Before a worker thread are about to read and update the local instance, they check the shared 
log for any fresh entry that was not seen during the last update. The update operations in these fresh entries are then 
applied to the local instance by a local thread. Since updates are communicated between nodes in a logical form, compared
with directly allowing worker threads to update a remote data structure, this approach minimizes the information that 
needs to be passed across node boundaries, and hence reduces NUMA communication. 

Since the implementation details of the data structure is unknown to the NR algorithm, no fine-grained synchronization
can be done. Instead, NR worker threads cooperatively finish operations, guaranteeing that at any moment, only one thread
can be performing updates on the data structure. This is realized using flat combining, which is described as follows.
In flat combining, a modification log is maintained with the data structure. If a thread wishes to update the data stucture,
it must insert into the log by atomically acquiring a log entry, and then store identify of itself, the operation descriptor,
and operation parameters in the log entry. After creating the log entry, threads then attempt to acquire a mutex and become 
the "combiner thread", which grants the permission of updating the data structure on behave of other threads. Threads that 
fail to acquire the mutex will spin on a local flag waiting for the return value. The combiner thread scans the log, 
marks all log entries from the current time in backward direction to the earliest entry that has not been processed, and 
then applies the entries one by one from the earliest to the latest. After fulfulling each log entry, the combiner thread
notifies the corresponding waiting thread to unblock them. After processing all log entries, the combiner thread releases 
the lock, and then proceed to do its own work. In the meanwhile, other worker threads can keep appending to the log
(the log does not use the same lock as the one held by the combiner thread). Entries appended after the combiner thread
scans the log will not be processed until the next iteration.

In NR, each node has an instance of the data structure, and hence each node runs one instance of the flat combining algorithm.
Update operations are not only posted on the local log, but also they should be conveyed to other nodes using a global log.
The global log is maintained as a circular buffer. The next available slot is indicated by a global variable "logTail".
Memory for the global log is allocated in a round-robin fashion from every node equally.
Each node also maintains a "lastTail" pointer, which points to the position in the global log when the node last synchronizes 
with the global log by. After the combiner thread acquires the mutex and marks local log entries, it first uses Fetch-And-Add 
(FAA) instruction to increment the 

