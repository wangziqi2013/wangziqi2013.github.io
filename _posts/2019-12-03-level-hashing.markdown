---
layout: paper-summary
title:  "Write-Optimized and High-Performance Hashing Index Scheme for Persistent Memory"
date:   2019-12-03 22:57:00 -0500
categories: paper
paper_title: "Write-Optimized and High-Performance Hashing Index Scheme for Persistent Memory"
paper_link: https://dl.acm.org/citation.cfm?id=3291202
paper_keyword: NVM; Hash Table; Level Hashing
paper_year: OSDI 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes level hashing, a hash table design for byte-addressable non-volatile memory. This paper identifies three
major difficulties of implementing hash tables on non-volatile memory. The first difficulty is consistency guarantees with
regard to failures. The internal states of the hash table must remain consistent, or at least must be able to be detected
after crash by the crash recovery process. This requires programmers to insert cache line write backs and memory barriers
on certain points to guarantee correct persistent ordering, which may hurt performance. The second difficulty is that DRAM-based
hash table designs may not particularly optimize for writes since DRAM write bandwidth is significantly higher than NVM 
bandwidth. On the contrary, on NVM based data structures, the number of writes must be minimized to accomodate for the lower
write bandwidth. Typical hash tables either use chained hashing or open addressing such as cuckoo hashing. Both schemes 
require excessive writes that are necessary for storing the key-value pairs. For example, in chained hashing, the linked
list under the bucket is modified to insert the newly allocated element, which requires both persistent malloc and linked 
list insertion. In cuckoo hashing, cascading writes may occur as a result of multiple hash conflicts. These writes are
not dedicated to storing the key-value paris but instead only maintains the internal consistency of the hash table.

Level hashing is a variant of cuckoo hashing, in which each element can be mapped to multiple locations in the hash table
using different hash functions (usually two). If the location has been occupied by another element, cuckoo hashing requires 
that the current element key in that slot be rehashed using the other hash function, and the element is stored in the alternate 
slot if it is free. This process may repeat for a few rounds until an empty slot is finally found, or the number of rounds 
exceeds a certain threshold, in which case the hash table needs to be resized. During a lookup, the search key is hashed by
both hash functions, and both slots are checked to see if they contain the search key. A hit is indicated if the key exists
in any of the two slots.

Level hashing improves cuckoo hashing in the following aspects. First, level hashing does not rely on logging (neither undo
nor redo) or copy-on-write to perform atomic writes of key-value pairs (which typically cannot be written with one atomic
store). Instead, key-value pairs are first written without being made visible to concurrent readers. A final update operation
on an 8-byte word atomically commits the write and makes them visible to concurrent readers. Second, 