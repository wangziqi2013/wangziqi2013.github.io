---
layout: paper-summary
title:  "Austere Flash Caching with Deduplication and Compression"
date:   2023-01-20 02:17:00 -0500
categories: paper
paper_title: "Austere Flash Caching with Deduplication and Compression"
paper_link: https://www.usenix.org/conference/atc20/presentation/wang-qiuping
paper_keyword: SSD; Caching; Flash Caching
paper_year: USENIX ATC 2022
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Comments:**

1. Although SHA-1/SHA-256 is extremely unlikely to collide and seems to never happen in practice, the paper should
still discuss the possibility of collisions and the handling of this situation. The discussion is necessary because
future advancements in cryptography may make SHA vulnerable to hash collision attacks. 

This paper proposes AustereCache, a flash (SSD) caching design that aims at lowering runtime memory consumption while 
increasing the effective cache size with deduplication and compression. AustereCache is based on prior flash caching 
proposals that implement deduplication and compression and is motivated by their high metadata memory footprint during 
the runtime. AustereCache addresses the problem with more efficient metadata organization on both DRAM and SSD. 
Compared with prior works, AustereCache substantially reduces in-memory indexing data structure size while 
achieving equal or better overall performance.

AustereCache assumes a flash caching architecture where flash storage, such as Solid-State Disks (SSD), is used in 
a caching layer between the conventional hard drive and the main memory. Since SSD has lower access latency but 
is more expensive in terms of dollars per GB, the cache architecture improves overall disk I/O latency without 
sacrificing the capacity of conventional hard drives. In the flash caching architecture, the SSD stores recently used
data in the granularity of chunks, the size of which is 32KB and is independent of the I/O size or the sector size
of the underlying hard drive. Each chunk is uniquely identified by the LBA. The cache can be either write-back or 
write-through, and AustereCache is effective for both of them.

The paper assumes the baseline workflow as follows. Chunk metadata is maintained in two indexing structures, namely the 
LBA index that maps chunk LBA to its fingerprint, and the FP index that maps the fingerprint to the physical location
of the chunk on the SSD. Both index structures are critical to the operation of the cache and must hence be loaded into
the runtime main memory for efficient reads and writes.
The LBA index uses chunk LBAs as keys and returns a pointer to an entry in the FP index, which is essential to
deduplication as it maps different chunks having the same content to the same fingerprint entry. The FP index uses 
fingerprint values as keys and returns physical pointers to chunk storage on the SSD cache.
Since multiple LBA entries can point to the same FP entry as a result of deduplication, each FP entry also maintains 
a list of back pointers, called LBA lists, which point to the LBA entries whose chunk data hash to the fingerprint 
value. The fingerprint, which is computed using SHA-1, uniquely identifies the content of a chunk, with the 
probability of collision being practically zero.

On disk read operations, the LBA of the chunk is first used to query the LBA index. If an entry exists, indicating that
the chunk exists in the cache, the fingerprint from the LBA index is then used to query the FP index, which returns the 
physical pointer of the chunk whose data is then read from its storage location.
On write operations, the cache controller first computes the SHA-1 hash of the chunk (if I/O size is smaller than
the chunk size, then this operation needs to read out the currently cached chunk and then apply the writes first)
as the fingerprint. Then the fingerprint is used to query the FP index. If an entry exists, the corresponding LBA
index of the updated chunk is updated to point to the new FP index entry. The LBA lists of the FP entries should
also be updated accordingly. 
In both scenarios, if an LBA or FP entry cannot be found, then the access misses the cache and must fetch data from
the underlying hard disk. In the meantime, an existing entry is evicted before the new entry
is inserted. The new entry is initialized using the LBA and/or the fingerprint value of the chunk to be accessed.
If the cache is write-back, then an additional dirty bit is added per LBA entry, and the chunk is written back
to the SSD when a dirty chunk is evicted.

Compression can be further applied to the baseline system to reduce the storage cost of every deduplicated chunk.
The paper suggests that LZ4 be used for chunk compression. After compression, chunks become variably sized data 
segments, and hence additional metadata is needed in the FP index to track the size of the compressed segments. 

Both deduplication and compression add a non-negligible amount of metadata which consumes precious runtime memory.
Using the simple back-of-the-envelope calculation, the paper argues that naive designs could end up with several times 
more memory usage than a design without deduplication and compression, which limits the effectiveness of 
flash caching as it reduces the amount of main memory that could have been available to cache frequently accessed 
disk data.

To address this problem, the paper proposes a new organization of caching metadata which we present as follows.
First, the LBA index is organized as a set-associative software cache. An LBA is mapped into an entry of the 
cache by first hashing the LBA and then using the lower bits as the set index to locate the set. Then the software
controller searches the set by comparing the rest of the bits in the hash value against the tags. A request hits the 
LBA index if one of the comparisons results in a match.

The FP index is organized similarly, except that it is now divided into two parts. The first part still resides in the
main memory, and it only contains partial tags (which is much smaller than the full tag, e.g., 16 bits) that 
could result in false hits. 
The second part of the FP index is moved to a reserved metadata region of the SSD. The in-SSD part has the same
set-associative organization as the in-memory part, but it stores the full tag as well as the back pointers. 
The data region of the SSD is also divided into chunk-sized blocks and organized the same as the FP index.
Consequently, every entry of the FP index has a corresponding block in the data region, which eliminates 
the need for physical pointers. 

With the new organization, FP index queries consist of two steps. In the first step, the hash of the FP value is 
computed, and the set is located. The software controller searches the set for a partial tag match and will immediately
declare a cache miss if no match can be found. However, if a match is found, due to the possibility of false hits, the
software controller must validate the search in the second step by checking the full FP index tag on the SSD. 
This operation does not need to search the on-SSD part of the FP index since the same set and way number
from the first step are used. The check will read the on-SSD part of the index into memory and then perform the 
final comparison. If the comparison indicates a tag match, the access hits the FP index and the physical location of 
the chunk can be computed from the set and way number of the FP index entry.

AustereCache also reduces the amount of metadata required for tracking compressed segment size in the baseline design. 
In AustereCache, compressed chunks are stored as consecutive sub-chunks in the data region of the SSD (and the 
last sub-chunk is padded to align to the sub-chunk boundary). 
The metadata of compressed chunks is stored in the corresponding FP index entry of the first sub-chunk. The rest 
entries in the FP index are marked as used but not accessed during normal operations.
A compressed sub-chunk can be accessed by first finding its FP index entry and then reading sequentially until the 
last sub-chunk.

Lastly, the paper proposes new eviction algorithms for both indices structures when an entry cannot be found.
For the LBA index, eviction is performed within a set, i.e., anytime a new entry is to be allocated, an existing entry
from the same set will be evicted. The eviction victim is determined using LRU algorithm where all entries 
of the set are maintained in a per-set LRU list. Index query that hits the cache will move the entry to the head of 
the LRU list, and so is a newly inserted entry. When an eviction decision is to be made, the LRU tail will be chosen
and then evicted. On eviction of an LBA entry, the corresponding back pointer in the FP entry is also removed.


