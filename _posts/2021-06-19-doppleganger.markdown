---
layout: paper-summary
title:  "Doppleganger: A Cache for Approximate Computing"
date:   2021-06-19 04:16:00 -0500
categories: paper
paper_title: "Doppleganger: A Cache for Approximate Computing"
paper_link: https://dl.acm.org/doi/10.1145/2830772.2830790
paper_keyword: Cache Compression; Deduplication; Doppleganger Cache
paper_year: MICRO 2015
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Doppleganger, an approximately compressed cache design. The paper noted that logical LLC capacity 
can be increased by performing compression, which improves overall system performance.
Conventional compression approaches either exploit inter-line redundancy by compressing each line individually
and storing them in a more compact layout, or exploit intra-line redundancy with block deduplication. In deduplication,
blocks with identical contents on different addresses are recognized, and instead of storing a copy of the block
for each address, only one instance of the block is maintained, which is then shared among multiple tag entries.

Doppleganger, on the other hand, identifies a third type of redundancy: value similarity between different blocks.
The design of Doppleganger is based on two important observations. First, many applications can tolerate value
precision losses at certain degrees. For example, in some graph processing applications, pixels of similar values can 
be sometimes considered as identical, as doing so will not affect the output of these algorithms.
This is called approximate computing, which has inherent error-correcting features and is therefore less stringent
on the exactness of data to certain degrees.
The second observation is that many data blocks indeed contains similar data in many applications. 
These blocks can be identified in the runtime using special hash functions, as we will see later.

Doppleganger employs content-sensitive hash functions to recognize similar blocks. 
The hash function maps blocks with similar contents to the same hash value with high probability. 
Doppleganger assumes that the block to be hashed must consists of values of the same type and possess the same
semantics. It relies on application programmers to provide the type and the logical value domain of the variables
stored in the block.
The hash is performed in two steps. In the first step, all elements in the block (the type of size of which is known)
are given to a hash unit, which computes two outputs: The average of these elements, and the range, defined as the 
difference between the maximum and the minimum. These two outputs are concatenated together, with the average
being the lower bits, and the range being the higher.
Note that the computations performed in this step are arithmetic operations on the logical value, rather than on
the binary value. This is extremely important is the data type is floating point numbers, since their arithmetics
must be performed by special floating point hardware, instead of regular binary ALUs.

In the next step, the value from the previous step is then mapped to an M-bit fingerprint value using linear mapping:
Given N-bit output from the previous step, the M-bit fingerprint is generated such that the smallest possible 
value of the N-bit output is mapped to zero, and the largest possible is mapped to (2^M - 1). The intermediate values
are mapped linearly, i.e., every consecutive range of size (2^N / 2^M) in the output value domain will be mapped to the 
same fingerprint value.
The paper also noted that it is possible that the output from the first step actually has smaller number of bits
then M (i.e., N < M). In this case, no linear mapping is performed, and the N bit hash value is directly used as 
the fingerprint.

We next describe the overall cache architecture. Doppleganger, as other conventional cache compression designs, 
decouples the tag array from the data array. The tag array is over-provisioned which allows more logical lines to
be encoded, potentially increasing the logical size of the cache (although the paper evaluates a design that uses 
the same number of logical tags but a smaller data array for the purpose of resource and power saving).
As in other deduplication designs, instead of enforcing a one-to-one correspondence between tag and data, it allows 
multiple tag entries to share the same data entry, thus saving the storage.

In addition to the address tag, coherence states, and other metadata (e.g., replacement states), tag entries
also store the fingerprint value of the address, and two pointers to other tag entries. These two pointers form
a doubly linked list between tag entries that share the same data entry.
Doppleganger implements the data array as a set-associative hash table using fingerprint values as keys.
Each data entry therefore consists of a fingerprint value tag (for key lookup), a data slot, and a back pointer
to the head of the doubly linked list that share the entry.
