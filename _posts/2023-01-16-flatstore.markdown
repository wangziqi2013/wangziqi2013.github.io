---
layout: paper-summary
title:  "FlatStore: An Efficient Log-Structured Key-Value Storage Engine for Persistent Memory"
date:   2023-01-16 03:35:00 -0500
categories: paper
paper_title: "FlatStore: An Efficient Log-Structured Key-Value Storage Engine for Persistent Memory"
paper_link: https://dl.acm.org/doi/abs/10.1145/3373376.3378515
paper_keyword: NVM; FlatStore; Key-Value Store; Log-Structured
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes FlatStore, a log-structured key-value store designed for NVM. FlatStore addresses the bandwidth
under-utilization problem in prior works and addresses the issue with careful examination of NVM performance 
characteristics and clever designs on the logging protocol. Compared with prior works, FlatStore achieves considerable 
improvement in operation throughput, especially on write-dominant workloads.

FlatStore is, in its essence, a log-structured storage architecture where modifications to existing data items 
(represented as key-value pairs) are implemented as appending to a persistent log as new data. In order for read
operations to locate the most recent key-value pair, an index structure keeps track of the most up-to-date value given
a lookup key, which is updated every time to point to the newly inserted key-value pair every time a modification
operation updates the value. Compared with conventional approaches that update data in place, a log-structured
key-value store transforms random writes to updated values to sequential writes at the end of the log buffer
and therefore demonstrates better write performance. Besides, the atomicity of operations can be easily guaranteed
because the update operation is only committed when the corresponding index entry is updated.

Despite being advantageous over the conventional designs, the paper noted, however, that prior works on log-structured
key-value stores severely under-utilize the available bandwidth of NVM, often falling behind to only using one-tenth
of the raw bandwidth. After careful investigation, the paper concludes that prior designs fail to utilize the full
bandwidth for two reasons. First, these designs keep the index structure in persistent memory which will be read
and written during operations. However, frequent reads and writes of the index are detrimental to overall performance,
since these reads and writes, however small they are, will saturate NVM bandwidth. The problem is generally worse 
with PUT (modification) operations, as these operations require updating the index, which itself may incur large 
write amplification (e.g., moving hash table slots, shifting B+TRee keys, etc.).
Second, prior works only assume that data can be flushed back to the NVM at 64-byte cache block granularity.
However, in reality, NVM internally performs reads and writes at a larger granularity, i.e., 256 bytes. The mismatch
between the granularity of cache block flushes and the granularity of hardware operations will degrade 
performance further.

The paper also observes a new trend in key-value workloads on production systems. First, most values are small, with
the size of the majority of objects being inserted fewer than a few hundred bytes. Second, today's workloads 
exhibit more fast-changing objects, indicating that these workloads are likely write-dominant. The paper hence concludes
that an efficient key-value store design should be specifically optimized to support small objects well and should be 
writer-friendly.

Based on the above observations, the paper proposes FlatStore to address the limitations of prior works and to leverage 
the new trends of commercial workloads. In order to design FlatStore for maximum bandwidth utilization, the paper lists
two critical performance characteristics of NVM. First, although sequential writes are faster than random writes 
with a few threads, when the number of threads increases, the performance gap between the two would narrow (as a 
possible result of internal resource contention), making it less beneficial to perform sequential writes instead of 
random ones when the thread count is large. Second, repeated cache block flushes using the clwb instruction on the same 
address will suffer extremely high latency, the cause of which is speculated to be either internal serialization of 
successive clwb instructions, or NVM's wear-leveling mechanism.
The design insight we can gather from this study, therefore, is that (1) an efficient design should perform sequential
writes only with a few threads, and (2) the design should avoid repeatedly flushing the same address as much as 
possible. 

We next present FlatStore design as follows. In FlatStore, both insertion of a new key and modification to an existing 
key are implemented as appending to a per-thread log segment. The log segment is allocated on the NVM as 4MB memory 
blocks aligned to the 4MB boundary, and each log segment has a tail pointer indicating the current tail of the log
which is also the next log allocation point.
A log entry consists of an "Op" field indicating the type of the operation (insert, modification, or delete),
a version ID field that stores the version ID of the key-value pair which is used for Garbage Collection, 
and two fields for storing the key and the value. The key field is 8 bytes, which can either be a key embedded
in the log entry, or a pointer that points to an externally allocated key. The value field contains variable-sized 
binary data, whose length can be between 1 byte and up to 16 bytes (with the value being encoded in the field as well).
Larger values are stored as an 8-byte pointer pointing to an externally allocated block.

FlatStore also maintains an index in volatile memory that tracks the most up-to-date key-value pairs for all keys
stored in all log segments. The index can be any mapping structure that, given a key, maps it to an address in the 
log. The index need not be persisted during runtime, since it can be restored on crash recovery by scanning the log
segments. However, on an ordered shutdown, the index is copied to the NVM such that it can be loaded back to 
volatile memory on the next startup.

FlatStore's modification operations (including insertions) are implemented as a three-stage process. In the first 
stage, the memory block for the key and/or the value is allocated, if they cannot be embedded within the log entry.
The externally allocated blocks, if any, are persisted using a persist barrier at the end of the stage. 
Then, in the second stage, the log entry is initialized at the current tail position, after which the tail pointer 
is incremented and persisted using another persist barrier. Lastly, the index is updated to commit the operation.
If the key already exists in the index, it is updated to point to the newly allocated log entry, and the 
Version ID field of the newly added entry is one plus the Version ID of the existing entry. Otherwise, the 
key is freshly inserted into the index, and its Version ID is set to zero.
No persist barrier is issued in this stage as the index is stored in volatile memory.

Both log segments and externally allocated keys and/or values are allocated by a custom allocator. The allocator 
requests free storage from the OS at 4MB granularity, and partitions them into smaller blocks which are maintained 
in size-segregated free lists for fast allocation. For non-log segments, each 4MB chunk also has a bitmap recording 
the allocation status of the rest of the storage in the chunk.
As for log segments, they are simply given away to individual threads and are maintained in a per-thread list. 
The per-thread list of log segments should be maintained properly such that all log segments that are in use
before a crash can be located for crash recovery.
The paper noted that the allocator metadata, mainly the bitmaps, do not have to be persisted at all in the runtime,
since allocation information is already included in the log entries, i.e., if a log entry contains a pointer to 
externally allocated blocks, then the 4MB chunk containing the block must be one of the allocated chunks.
During crash recovery, the allocation metadata can be restored by scanning the log, locating every 4MB chunk
that contains externally allocated blocks, and then reconstructing allocation metadata. The head of the chunk
can be easily found by aligning block pointers down to the nearest 4MB boundary because all chunks are aligned to
this address boundary.

To address the problem that sequential write performance degrades with an increasing number of worker threads, 
FlatStore proposes a technique called "Horizontal Batching" that enables a dedicated core to persist log 
entries on behalf of all other cores. In FlatStore, incoming requests are dispatched to cores based on the 
hash value of the keys. On receiving a request, a core will first perform stage one locally (i.e., allocating 
key and/or value blocks if necessary). At the end of stage one, it will insert the log entry into a 
local volatile work-stealing buffer. After the first stage, the core will then attempt to become the leader by 
grabbing a global lock. If the lock is acquired successfully, the core will then start collecting log entries from 
all other core's work-stealing buffers, appends the log entries into its own log segment, and updates the index, hence 
completing stage two and stage three. 
After completing the stages, the core will then set a flag in the work-stealing buffers to indicate that the operation
has succeeded, and then release the global lock. 

