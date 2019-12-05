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
nor redo) or copy-on-write to perform atomic writes of key-value pairs, which typically cannot be written with one atomic
store. Instead, key-value pairs are first written without being made visible to concurrent readers. A final update operation
on an 8-byte word atomically commits the write and makes them visible to concurrent readers. Second, level hashing simplifies
resizing by only rehashing a subset of keys instead of all keys. The rehashing process co-operates with normal reads and 
inserts such that they are not blocked by the resize. This is accomplished by a two-level structure of buckets. The third
contribution of level hashing is that it reduces the number of cascading writes to a minimum. In most cases, the element
can find an empty slot in the first attempt. Even in the case of a rehash, at most one cascading write will be used to move
existing elements to their alternate locations. 

We next describe level hashing data structure as follows. The hash table consists of two bucket arrays, one upper level 
array, and another lower level array. Arrays consist of buckets, which contains several slots (less than 64). This paper 
assumes four slots per bucket to , but the design itself does not prevent more slots. For elements that are mapped to upper 
level bucket k, they can also be stored in lower level bucket floor(k / 2). Two hash functions are used to map an element
to two buckets in the upper level array, and these upper half array can use the corresponding lower half array to handle 
overflows. The advantage of using two levels of buckets is that table resizing can be as simple as adding a third level
on top of the current upper level, after which elements in the lower level can be moved gradually to the third level by
rehashing them. 

An insert operation in level hash table works as follows. We first hash the key using both hash functions, and check whether
the two buckets in the upper level and the two buckets in the lower level already have the key. If not, the insertion process
writes the key-value pair into one of the two upper level buckets, whichever has at least one free slot (if both are not 
full, then select the one with fewer elements). If both buckets are full, we then try to move one of the elements in the 
two top level buckets to its alternate location, by hashing the element again using the other hash function, and probe
whether the alternate bucket is also full. If this is impossible for all eight elements in upper level buckets, we then
proceed to the two corresponding lower level buckets and attempt to insert the element there using the same criterion. If, 
unfortunately, both lower level buckets are also full, we also try to move elements to its alternate lower level bucket 
to make space for the newly inserted element. If this cannot be done, then the hash table needs a resize, which will be 
described later. Note that in the insertion scheme described above, we prioritize inserting into the upper level over inserting
into the lower level. This is because the number of buckets in the lower level is only half of the number of buckets in 
the upper level, which implies higher chance of conflicts compared with the upper level. A conflict in lower level buckets 
will trigger a hash table resize, which is relatively expensive. Giving priority to the upper level can increase the 
load factor of the hash table before the next resize, as reported by the paper.

Searching operation is simple: We first probe the two upper level buckets to search for the key. If key is not found, we 
further probe the two bottom level buckets. Only two hash functions are computed and four buckets are searched in the 
worst case. 

When the table is resized, we first create an array of buckets whose size is double the current upper level size as a 
third level. Bucket k in the third level uses bucket floor(k / 2) as the overflow bucket, just like bucket k in the 
upper level uses bucket floor(k / 2) as overflow bucket. After creating the third level, all new inserts must only
insert into the third level and the current upper level, while read operations must probe all three levels, checking 
a maximum of six buckets. In the meantime, the resizing thread rehashes all elements in the current lower level. It is
guaranteed that rehashing will not cascade due to conflicts on the third and upper levels, since each bucket in the 
lower level is mapped to four buckets in the third level. After all elements in the lower level are rehashed, the current
lower level is removed, and the previous upper level becomes the current lower level. 

To ensure atomic update, each bucket has a bitmap in its header. The bitmap is 8 byte in size, and is aligned to word boundary.
Each bit in the bitmap represents whether the corresponding slot in the bucket is used or not. In addition, each slot has 
a ont-bit spin lock to ensure exclusive access of the key-value pair for synchronizing between concurrent writer threads. 
When we insert an element into the node, we first check the bitmap of the bucket to find a free slot. After a free slot
is found, we lock the slot by atomically setting the bit flag of the slot. Next, the key-value pair is written into the 
slot using regular writes, and then flushed back to the NVM. This write process does not need to be atomic, since the 
bitmap has not been set yet, and hence the pair is invisible. In the last step, we set the bitmap header, write back
the bitmap to the NVM, and unlock the slot. Only after we set the header could concurrent reader threads access the pair.
Reader threads, on the other hand, do not need to acquire the per-slot lock to access the key-value pair, because partially
written key-value pairs will not be marked in the bitmap. If the system crashes before the bitmap is set, the insertion
is naturally rolled back as if it has never happened. For deletes, we simply check that the deleted key truly exist in
one of the four possible buckets, and then unset the bit in the bitmap before flushing the bitmap back to the NVM.

The paper 
