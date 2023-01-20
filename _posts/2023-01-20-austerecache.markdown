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

AustereCache assumes a flash caching architecture where flash storage, such as Solid-State Disks (SSD), are used in 
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

