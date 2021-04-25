---
layout: paper-summary
title:  "FlatStore: An Efficient Los-Structured Key-Value Storage Engine for Persistent Memory"
date:   2020-07-25 05:21:00 -0500
categories: paper
paper_title: "FlatStore: An Efficient Los-Structured Key-Value Storage Engine for Persistent Memory"
paper_link: https://dl.acm.org/doi/abs/10.1145/3373376.3378515
paper_keyword: NVM; FlatStore; Log-structured
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Making the memory allocation commit with the commit of the log entry can achieve atomicity naturally between allocation
   and the update operation, since allocations that are not in a valid log entry will be automatically rolled back

2. Synchronizing log commits using flat combining: Only one thread is delegated as the combiner at a time, which collects
   requests from other cores and updates the shared data structure on behalf of othe cores.
   Requests for the same key are serialized on a certain core.
   This also solves the workload skew problem.

3. The data layout design allows finding the base block with the pointer value by aligning the value down to 4MB boundary

**Questions**

1. How to keep atomicity of GC? How to make sure that log chunk allocation and free are always atomic?

This paper proposes FlatStore, a log-structured key-value store architecture running on byte-addressable NVDIMM, which
features low write amplification. 
The paper identifies a few issues with previously proposed designs. First, these designs often generate extra writes to
the NVM, in addition to persisting keys and values, for various reasons. The paper points out that in a conventional
key-value store where all metadata are kept on the NVM, on each key-value insertion or deletion, both the indexing structure 
and the allocator should be updated to reflect the operation. Even worse, most existing indexing structure and allocators 
are not optimized specifically for NVM. For example, for B+Tree structures, a leaf node insertion involves shifting 
existing elements to maintain the sorted property; Similar overheads exist for hash tables, where rehashing or element
relocation is required when the load factor exceeds a certain threshold.
Second, many designs are incorrectly optimized with techniques such log-structured storage. These optimizations may work
well for conventional disks or SSDs, but are incompatible with NVDIMM. The paper points out two empirical evidences that 
may affect the design.
First, repeated cache line flushes on the same address will suffer extra delay, discouraging in-line updating of NVM
data. This phenomenon becomes even more dire given that the access pattern is usually skewed towards a few frequently
accessed keys, further aggravating the latency problem.
The second observation is that the peak write bandwidth is achieved when the write size equals the
size of the internal buffer (256 bytes), and remains stable thereafter when multiple threads write into the same device 
in parallel. One of the implications is that writing logs in a larger granularity than 256 bytes will not result in
higher performance, contradicting common beliefs that the larger the logging granularty is, the better performance it 
will bring. Larger logging granularities, however, negatively impact the latency of operation, since an operation
is declared as committed only after its changes are persisted with the log entries.

FlatStore overcomes the above issues with a combination of techniques as we discuss below. First, FlatStore adopts the
log-structured update design to avoid inline updates of data, converting most data updates to sequential writes.
Update operations are first aggregated in the DRAM buffer, before they are persisted to the NVM via group commit.
In addition, log entries are flushed frequently in 256 byte granularity to minimize operation latency. To support
small log entries, FlatStore uses two distinct log formats. If the key and value pair is sufficiently small to be contained
in a log entry, then they will be written as inline data within the entry. Otherwise, the log entry contains pointers
to the key and value, which are stored in memory blocks allocated from the persistent heap.
Second, to reduce write amplification, neither allocator metadata nor the index structure is synchronized to the NVM
during normal operation. Instead, they are only maintained in the volatile DRAM, serving as a fast runtime cache.
Both types of data can be recovered from the log during recovery, as FlatStore uses the persistent log as the ultimate
reference for rebuilding the pre-crash image.
Lastly, to further reduce operation latency, which may be affected by the group commit protocol, FlatStore proposes a 
novel log stealing mechanism to allow uncommitted requests on less active cores being "stolen" by another core and
then committed to the NVM. This mechanism is performed in a pipelined manner to avoid unnecessary blocking, as we will 
see below.

The main data structure of FlatStore is the log object. Logs are allocated in the unit of large chunks, whose allocation
and deallocation must also be logged in the metadata area located at the beginning of FlatStore storage. The log serves
as the ultimate storage for objects, which contains all necessary information to rebuild other auxiliary data structures
after a crash. To minimize log size and write amplification, FlatStore tracks operations using logical logging,
meaning that only logical operations that mutate the state, such as PUT and DELETE, will be stored. Low level reads and 
writes to the underlying data structure will not be logged, since FlatStore can always restore their states by
reading the log on a recovery. A global log tail pointer is maintained to indicate the next log write location. The 
tail pointer is always updated with a global lock held, which protects the log and ensures atomicity of operations.
The usage of a global lock will not cause severe contention problem, as we will see later, since threads do not content
for the lock for each update operation. Instead, FlatStore designates one of the threads as the leader thread, and performs
group commit on behalf of all other threads with the assistance of log stealing.

Two types log entries exists: a value-based entry stores both keys and values inline to allow fast access and less NVM 
writes, while a pointer-based entry stores a pointer to the value object allocated from the heap. FlatStore assumes 8-byte
key objects, which can themselves be pointers to heap-allocated key objects as well. 
Both types of log entries contain an op field describing the operation, a type field, a version field, and a key field.
For value-based entries, an extra size field and variable-sized inline value field also follow, which will be
replaced by a value pointer for pointer-based entries.
As already stated above, log entries are always grouped into 256-byte batches and then committed using the log stealing
protocol after gaining exclusive access. If a batch cannot make 256 bytes, the entry will be padded with all-zeros until
256 byte boundary is reached.

Value objects are allocated from the persistent heap, which is maintained by a customized allocator. The allocator 
does not actively synchronize its metadata to the NVM to minimize bandwidth consumption and write amplification
except during the shutdown process. 
The allocator, which, according to the paper, uses an algorithm similar to the one in Hoard. Free memory is divided into
aligned 4MB chunks, which are then further divided into individual blocks of different size classes. Each chunk can only 
serve one size class, which is persisted at the chunk header during initialization. The chunk header also maintains a bitmap
which tracks the allocation status of each block. The allocator maintains all other metadata in the volatile DRAM,
which will be lost in a crash. On receiving an allocation request of size K, the allocator performs memory allocation of
size (K + 8) as a conventional DRAM allocator, and then stores the allocation size in the first 8-byte word. The returned
address is also incremented by eight (and decremented by eight accordingly before it is freed). The memory allocation is 
committed only after the log entry that contains the pointer is committed. Otherwise, the allocation as well as the operation 
in the log will be rolled back automatically after a crash, which maintains the atomicity between memory allocation and 
the update operation.

On crash recovery, the allocator metadata is restored by first scanning the log, and for each valid pointer-based entry 
in the log, the 4MB chunk header is located by rounding down the pointer value to the nearest 4MB boundary. The size field,
which is stored in the 8-byte word right before the pointed-to memory, is used to determine the number of blocks
in the 4MB chunk that have been allocated. The allocation bitmap in the header is updated accordingly to reflect the 
allocation. Memory blocks that are not set are considered as uncommitted, whose allocations are naturally rolled back 
by the crash.

A volatile index is maintained as the non-clustered index mapping keys to log entries. The paper suggests that either 
an in-memory hash table or Masstree can be employed as index. The index is concurrently accessed by all threads. 
For hash tables, locking is performed on a per-bucket basis to eliminate most of the contentions. For Masstree,
since the data structure is already concurrent, no extra locking is required.

Client requests are dispatched to threads based on the key hashes. The same key request will always be hashed to the same
thread, which preseves the ordering of requests on the same key. FlatStore threads always process requests serially. 
On a read operation, the index is searched to locate the log entry. If none can be found, an NAK is responded to indicate
that the key does not exist. On an insert or update request, the index is first searched. If the key is not found, then
a new log entry with version number being zero is generated, and the key is also inserted into the index. 
If the key is found, then the current log entry becomes obsolete, and a new log entry with a large version number is generated
and persisted. The index is also updated to reflect the new value. A version number is stored with each index entry, and
updated to the new log entry's version number when the entry pointer is updated. Version numbers help the GC process to
identify stale entries, as we will see below. 

As a log-structured engine, FlatStore requires regular garbage collection to remove stale entries. The background thread
performs GC in log chunk granularity. For each log entry in the chunk, it searches the key in the index. If the key can 
be found, and versions do not match, then the entry is stale, which can be ignored. Non-existing keys also indicate stale
entries. A new chunk is then allocated, with all valid entries in the old chunk being copied to the new chunk. Pointers
in the index are updated to point to addresses in the new chunk. The old chunk is freed after the GC. The log chunk
allocation information is also updated in the metadata area.

On a normal shutdown, a shutdown process flushes the DRAM index and allocator metadata back to the NVM to accelerate 
normal startup. A flag is also set to indicate normal shutdown, which will be checked on startup.
If the flag indicates a normal shutdown, then both the index and allocator metadata are loaded from the NVM. 
Otherwise, a crash mush have happened, and FlatStore invokes the crash recovery process to rebuild the in-memory
data structure and fix potential inconsistencies of the allocator metadata. 

The last feature of FlatStore is Horizontal Batching (HB), which employs log-stealing and flat-combining to: (1)
synchronize log updates from different threads; (2) Minimize operation commit latency; and (3) Eliminate load
imbalancing caused by skewed key distribution. 
Each thread maintains a log queue in a known memory location, which holds log batches generated by that thread.
Instead of allowing all threads to update the tail pointer concurrently, which causes data race, FlatStore
selects a leader thread as the one responsible for persisting log entries, and keeps other threads wait for
notifications from the leader threads on the completion of persistence. The leader thread is selected by having
all threads contending for the global lock, and the one who successfully acquires the lock becomes the leader.
All other threads become followers, which must wait for the leader's signal before they can acknowledge to clients. 
To avoid unnecessary blocking of follower threads, these follower threads are allowed to continue handling requests
from the clients to form the next batch. After the global lock is released, follower threads with at least one batch
can immediately attempt to acquire the lock and become the leader. Only very few cycles are wasted on lock
contention in this case. FlatStore calls this "Pipelined HB".
On large scale systems, such as multi-socket systems, only having one global lock may be infeasible. The paper 
also suggests that more than one leader can be chosen by using different locks and partitioned logs. It is 
recommended that one leader per socket is chosen for updating a per-socket log partition, in order to minimize
inter-socket traffic.
