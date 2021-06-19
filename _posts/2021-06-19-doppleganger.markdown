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