---
layout: paper-summary
title:  "Elastic Cuckoo Hashing Tables: Rethinking Virtual Memory Translation for Parallelism"
date:   2020-12-29 18:12:00 -0500
categories: paper
paper_title: "Elastic Cuckoo Hashing Tables: Rethinking Virtual Memory Translation for Parallelism"
paper_link: https://dl.acm.org/doi/10.1145/3373376.3378493
paper_keyword: Virtual Memory; Page Table; Cuckoo Hashing
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Elastic Cuckoo Hashing Table (ECHT) and a new virtual memory address mapping framework for more
efficient page walks and translation caching.
The paper begins by identifying a few limitations of current page table design and research proposals. 
The current design, using radix tree as the table and bit slices of the address to index each level of the tree,
suffers from squential read problem, since the next level in the radix tree can only be determined after the 
previous level is read from the memory.
In addition, many modern implementations add page walk caches to further accelerate page table walk. The intermediate 
levels of the radix tree will consume cache storage while not contributing to translation, if lower level entries
are also cached.

To overcome the extra indirection levels of a radix tree, some prior proposals suggest that hash tables should be used 
for fast, low latency search. Hash tables, however, are also not perfect candidates for this purpose, due to several
problems. First, hash conflicts can occur, especially when the table is densely populated. Common conflict resolution
approaches, such as open addressing and chaining, will not work well for a hardware page walker, since they also
incur extra levels of indirection or sequential memory access, which can even be slower than radix trees.
Second, hash tables require constant resizing when being inserted into. The resizing operation either needs a long 
latency full-table copy and rehashing, or can be done lazily by allowing both the old and new table to be present, 
at the cost of increased number of memory accesses and storage consumption.
Third, the paper also claims that none of the prior hash table proposals support multiple page sizes in the same table,
neither can they support process-private page tables, complicating common tasks such as address iteration for a 
certain process and huge pages.

To address these challenges, the paper proposes adopting cuckoo hashing into page table designs. Cuckoo hashing is a 
conflict resolution algorithm that allows the conflicting key to be rehashed to a different location when conflict 
occurs. In Cuckoo hashing, multiple hash algorithms are implemented. The hash value is directly mapped to the table's
element array. If a key conflict occurs, i.e., a different key already exists on the slot, the original key will be
rehashed using a different hash function than the most recent, and be inserted into the location indicated by the
new hash function. This process can recursively rehash other keys if conflicts continue to occur, until a certain
threshold is reached, in which case the insertion fails.

The paper assumes the following baseline Cuckoo design. The hash table consists of N element arrays and N hash 
functions. Function i maps a key into element array i. Conflicts on element array i during insertion is resolved
by rehashing the original key into a randomly selected array except the current one.
Table lookup is performed in parallel by first hashing the requested key with all hash functions in parallel, and
then probing each element array using the hash value as the index. A hit is signaled if one of the arrays indicate
a key match.
When insertion failure occurs, if the table is not currently being resized (discussed later), then resize will
be triggered immediately. Otherwise, existing elements in the table is rehashed using a different function, and
insertion is tried again. The table has two parameters: One is load factor, the other is multiplicative factor.
The load factor is a ratio between zero and one. It serves as an upper bound for how populated an element array
could be before a resizing takes place. In other words, during the operation, if the ratio between valid elements
and total number of slots exceeds the load factor, then resizing is triggered.
The resize operation, as we discuss in full details later, allocates a new table with the same number of 
element arrays, with the size of each array being larger than the previous one. The ratio between new and old element
array sizes is determined by the multiplicative factor. The paper suggests that both parameters be selected carefully
based on the number of ways of the table.

We next describe the resizing operation. The paper uses lazy resizing, which has shorter latency, but must go through
a transient state where both old and new tables are present, during which elements in the old table is gradually
rehashed into the new table. 
This baseline resizing design, however, doubles the number of hash computation and memory requests during lookup, 
since now the requested key can reside in all arrays of both tables.

To reduce the overhead, the paper proposes a slightly different resizing algorithm we desscribe as follows. Each way
of the old table maintains a low-watermark pointer. The algorithm then maintains the invariant that all elements 
below the pointer in the array must have already been migrated to the new table. 
Initially, all pointers are set to the beginning of the array. Table insertion still starts at the old table by
randomly selecting an array as the starting point.
Before the insertion actually takes place, the element pointed to by the corresponding pointer in the array being inserted into will be rehashed to the new table, and the pointer is incremented until the next valid element is reached
or the array is completed.
Then insertion continues by hashing the requested key, and check whether the hash value falls into the "completed"
part of the array, or otherwise. In the first case, since the invariant that all elements whose hash value
fall into in that part have already been rehashed into the new table, the insertion will then be performed on the new
table. Otherwise, the insertion is performed on the old table, with possible rehashing of an existing element
in the element array. In this case, all recursive insertion must start at the old table, and follow the same algorithm 
described above.
