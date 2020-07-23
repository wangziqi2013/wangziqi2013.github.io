---
layout: paper-summary
title:  "Thesaurus: Efficient Cache Compression via Dynamic Clustering"
date:   2020-07-23 04:33:00 -0500
categories: paper
paper_title: "Thesaurus: Efficient Cache Compression via Dynamic Clustering"
paper_link: https://dl.acm.org/doi/10.1145/3373376.3378518
paper_keyword: Compression; Cache Compression; Fingerprint hash; 2D compression; Thesaurus
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Thesaurus, a cache compression scheme with dynamic clustering. This paper points out at the beginning
that two existing methods for increasing effective cache sizes, cache compression and deduplication, are both suboptimal
in terms of compression ratio. Cache compression tries to exploit redundancy and dynamic value range in individual
blocks or limited number of blocks using certain compression algorithms. It failed to admit inter-line redundancy or
only provides naive solutions such as compression multiple lines together as a larger block. In fact, however, many
workloads in this paper indicate that there is abundant amount of inter-line redundancy between two cache lines. These
redundancies can be encoded more efficiently as byte deltas between the two lines, which is difficult to explore with
conventional cache compression, since they only compress blocks sequentially.
On the other hand, cache deduplication removes duplicated lines using special hardware structures such as hash tables.
Incoming lines are checked with the hash table first for hash matches, and full value comparisons are conducted
later to verify if the two lines actually match. The paper argues that deduplication also failed to catch some redundencies,
since many cache lines do have identical bytes despite the fact that they are not duplications.
