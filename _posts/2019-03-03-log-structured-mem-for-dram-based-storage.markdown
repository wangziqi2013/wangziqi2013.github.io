---
layout: paper-summary
title:  "Log-Structured Memory for DRAM-based Storage"
date:   2019-03-03 02:11:00 -0500
categories: paper
paper_title: "Log-Structured Memory for DRAM-based Storage"
paper_link: https://www.usenix.org/conference/fast14/technical-sessions/presentation/rumble
paper_keyword: Log-Structured; NVM; Durability
paper_year: USENIX FAST 2014
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper introduces log-structured key-value store based on RAMCloud, a state-of-the-art key-value store using non-log-structured 
architecture. The paper identifies the problem with traditional memory allocators: fragmentation. The paper claims that 
traditional memory allocators such as glibc malloc() is only efficient when the application has a relatively stable DRAM
allocation pattern. If the pattern changes, a worst case of 50% space waste has been observed using synthetic workloads
on all allocators.

This paper points out that allocators can be divided into two types: non-copy allocators and copy allocators. Non-copy allocators,
such as malloc(), never moves the location of memory blocks after they are allocated. Non-copy allocator, on the other hand,
can move the location of blocks even after allocation. In practice, non-copy allocator is most likely the one used by 
general applications, because it would be impossible to move blocks around without knowing all poionter references to the block.
Copy allocators, however, utilizes memory better by periodically compressing the address space and thus reducing memory
fragmentation. In such an environment, memory accesses cannot be made directly using pointers, since the pointer may
point to an invalid block which is already relocated. 

This paper assumes that the system runs RAMCloud, an in-memory key-value store supporting high throughput query and durable 
object storage. Its main in-memory component is a hash table, which maps keys to immutable objects. Objects must not be modified
partially: An object modification operation from clients must upload a new object and change the key-value mapping from 
the old object to a new one. The on-disk component maintains a log which is the durable replica of in-memory component. 
Every operation executed by the in-memory component must be reflected to the on-disk log before they can return results to
the client. To further improve safety, each durable log is also replicated on a few peer servers. Operations must also 
wait for information to propagate to peer servers before they can return.

RAMCloud maintains a global log object, which is further divided into smaller units, called segments. Each segment is 
usually 8MB in size, and can be allocated from the heap using a simple slab allocator. Threads append new objects to the 
head of the log, and perform garbage collection from the tail of the log. When a new segment is created, a special record, 
the segment digestion, is written at the beginning of the segment. The sement digestion is a list of all valid segments 
(i.e. contain non-stale data). Every segment in the system is assigned a unique and non-decreasing segment identifier. 
The digestion in the new segment is marked as active, after which the segment is persisted onto the disk. The digestion 
in the previous segment is then marked as inactive, and it is also persisted. The invariant we maintain is as follows: At 
any time in the system, the number of active segments is at most two and at least one. On recovery, the handler first scans
the log to locate the most recent segment using the segment IDs (since they are monotonically increasing). The segment digest
contains a superset of all valid segments in the system before the crash (since segments might be garbage collected after
the new segment is created). If there are two segments both having an active digest, the segment with a larger ID wins,
and the other is marked as inactive. The recovery handler then locates all valid segments using the digest found in the 
header, and proceeds to restore the state.

The log-structured aechitecture work as follows. On an object allocation, which happens on both inserting new keys and modifying
existing objects, the object is appended to the head of the current log. The in-memory hash table is then updated to point
to the new object. On an object deletion, the existing object in the log will not be written into. Instead, a special tombstone 
record is appended to the head of the log, indicating the deletion of existing entries. Tombstone records are ignored during
normal operations. On recovery, objects marked by the tombstome record will not be part of the restored state. As we will show
later, tombstone objects introduce special problems for garbage collection, and need to be treated in a slightly different way.
In all the above cases, both the in-memory copy and the on-disk copy of the log are kept synchronized. Remote copies are 
also updated accordingly.

Garbage collection (GC) works similarly to a log-structured file system. The GC thread scans segment from the tail of the 
log. The scan proceeds segment by segment. For each log record in a segment, the GC thread checks the hash table to see 
if the entry is stale or not. A stale entry is recognized by the fact thet the key recorded in the entry does not exist 
in the hash table, or the key exists but the object pointer does not match the log record's address. In either case, the 
object is marked as stale. If too many stale objects are found in the log, the segment will be marked as eligible for GC.
The GC process then copies all valid objects from the segment into a new segment, and appends the new segment to the head 
of the log. Hash table entries for valid objects are also updated to point to objects in the new segment. Tombstone records
introduce a little bit problems in this process, because the tombstone record will not become stale unless the segment of 
the object it refers to is garbage collected. In other words, if the tombstone record is in the same segment as the deleted
object, the tomestore record can be removed freely. If, however, that these two are not in the same segment, then a GC 
dependency is created, which must be obeyed by the GC thread. The simplest way to deal with this is that if the segment
has not been collected when a tombstone record is scanned, the tombstone record will not be marked as stale, and will
be copied to the new segment.

The paper also points out that a dilemma exists between memory utilization and available bandwidth, which prevents the 
simple scheme described above from working well. If the system is to maintain high utilization of memory, then for each 
segment collected, on average, only a small fraction of stale objects will be truly freed. That is to say, the majority 
part of the segment to be cleaned will be copied to the new segment, which can easily become a bottleneck given that all 
segment creation must be reflected to the disk. To solve this problem, the paper proposes a two-level GC scheme. On the 
first level, the GC thread only compresses segments in DRAM without reflecting them to the disk version. A smaller granularity
of allocation is required to satisfy the needs, which is called seglets. Seglets are smaller units whose size is usually 
tens of KBs for composing larger segments. On garbage collection, a full-sized segment is compressed into a smaller segment,
and then appended to the head of the in-memory log. This process does not involve disk I/O, and can hence be completed with
relatively higher bandwidth. During first level claning, it is maintained that for each segment (having varying sizes) in
DRAM, there is always a corresponding full-sized segment on the disk having identical logical content. The only difference
is that the DRAM version of the segment can be smaller than the one on the disk. On the second level, the disk version
segment is also cleaned, which requires copying live data to the head of the disk log and hence consumes I/O bandwidth. 
Since GC for disk segments are postponed, it is likely that more objects have freed since last time first-level GC
is conducted. In fact, we can upper bound the amount of work on second level GC. Given that the DRAM usage of segments
can be seen as an upper bound of the actual amount of valid data, if we allow the disk image to be at least twice 
the size of the DRAM log, we know that disk segment utilization must always be less than 50%. 