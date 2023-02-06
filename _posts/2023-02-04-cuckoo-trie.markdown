---
layout: paper-summary
title:  "Cuckoo Trie: Exploiting Memory-Level Parallelism for Efficient DRAM Indexing"
date:   2023-02-04 19:23:00 -0500
categories: paper
paper_title: "Cuckoo Trie: Exploiting Memory-Level Parallelism for Efficient DRAM Indexing"
paper_link: https://dl.acm.org/doi/10.1145/3477132.3483551
paper_keyword: B+Tree; Trie; Cuckoo Hashing; Cuckoo Trie
paper_year: SOSP 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

**Comments:**

1. Why using the complicated two-step hashing scheme to compute the alternative bucket for relocation?
Why not just compute the two buckets and store both of them in the entry?
Besides, it seems that t is much smaller than S (t = 16 and S is the number of buckets). However, the hash
function f() maps from the value domain of t to the value domain of S. What is the purpose of such a mapping?

This paper presents Cuckoo Trie, a hashed radix tree (trie) representation that utilizes memory-level parallelism 
for more efficient lookups. The paper is motivated by the low memory-level parallelism of conventional pointer-based 
ordered indexing structures, such as B+Trees and radix trees. The paper focuses on radix trees and addresses 
the problem with a hashed representation of the radix tree nodes, such that nodes on the tree traversal path can be 
prefetched using key prefixes. Compared with conventional pointer-based radix tree implementations that serialize 
the memory accesses at each level, Cuckoo Trie demonstrates higher operation throughput on certain workloads.

The paper begins by observing that modern out-of-order hardware has a high degree of memory-level parallelism. In
particular, the hardware can execute non-dependent memory instruction out-of-order and tolerate multiple cache misses
until the hardware resources such as MSHRs are saturated. However, the capability of performing memory operations in 
parallel is often under-utilized by conventional implementations of radix trees, as in these
implementations, the next level of tree traversal can only be obtained after the parent level is fetched from the 
memory hierarchy. To make things worse, on modern big-data workloads, the amount of working set data will likely
exceed the size of the cache hierarchy, meaning that the memory accesses will suffer cache misses on all levels
and be satisfied by the main memory serially. Consequently, the overall performance of these implementations will 
degrade as the working set is becoming larger due to the lack of memory-level parallelism.

The Cuckoo Trie design is based on Bucketized Cuckoo Hashing. In Bucketized Cuckoo hashing, the hash table is organized
as a software set-associative lookup structure. Each set is called a bucket and consists of `s` items. Keys are
hashed to two values that correspond to two buckets in the table, and a key can reside in any of the items of the 
two buckets. Lookup operations in the bucketized cuckoo hash table take constant time as only two buckets that
the key can map to are checked. Insert operations, on the other hand, may require multiple key relocations if 
conflicts occur. More specifically, on key insertions, if both buckets that the key maps to are full, then a 
victim key from one of the two buckets needs to be relocated to the alternate bucket of the victim key in order
to free up an item slot. This relocation process may potentially happen recursively several times if the other
bucket of the victim key is also full, and can fail eventually after a certain number of attempts. However,
the paper suggests that Bucketized Cuckoo Hashing can sustain a high load factor that is usually greater 
than 90% before the inevitable failure. In this case, the hash table is resized and the existing items are rehashed
to the newer and larger table. This resizing process can be overlapped with normal operation on the old table
using a high-water mark indicating the progress of rehashing. Items that fall under the high-water mark are
already rehashed to the newer table, and therefore, operations on these items must be conducted on the new table. 
On the other hand, items that are still above the high-water mark are in the old table, and correspondingly,
modifications to these items must be conducted on the old table.

With Bucketized Cuckoo Hashing, a radix tree can be represented as hashed nodes stored in the table instead of 
being linked together by explicit pointers. Logically speaking, each item of the hash table consists of a 
key prefix that the node encodes (i.e., the string of tokens in order to reach the node from the root), which is also
the lookup key of the item; a bitmap indicating the availability of child nodes, the size of which equals two to
the number of bits in each token; two pointers delimiting the range of leaf nodes that the node covers (if the node
if a leaf node, then the pointers are undefined), and a type field to indicate whether the node is an inner node or 
a leaf node. Lookup operations on the Cuckoo Trie are performed as follows. First, the lookup procedure issues D
prefetching requests to prefetch the buckets that can contain the first D nodes on the traversal path.
For radix trees, the lookup keys for the nodes on the traversal path can be easily computed using the first D 
key prefixes. The depth of prefetching D depends on the degree of memory-level parallelism of the system and 
can be empirically measured. Then the lookup process begins by performing lookups on the hash table using 
the key prefixes, adding one more token to the prefix after going down a level, until a leaf node is reached.
For each level that has been traversed, the lookup procedure also issues new prefetch instructions for key
prefixes that are D tokens ahead, striving to keep the memory pipeline busy and fully utilize the memory bandwidth.

The above naive approach needs to store a node's key prefix in each entry for two purposes. First, when the entry 
is relocated to its alternate bucket, the key prefix is essential for computing the index of the alternate bucket.
Second, the hash table lookup procedure also compares the key prefix stored in the entry against the lookup key
to verify that the node is indeed the one that matches the search key rather than hash conflicts.
However, storing each node's key prefix in the hash table entry brings unnecessary storage 
overhead and increases the extra work on every hash table lookup, and the paper hence proposes to not store them.


