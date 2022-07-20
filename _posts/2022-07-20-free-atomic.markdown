---
layout: paper-summary
title:  "Free Atomics: Hardware Atomic Operations without Fences"
date:   2022-07-20 03:56:00 -0500
categories: paper
paper_title: "Free Atomics: Hardware Atomic Operations without Fences"
paper_link: https://dl.acm.org/doi/10.1145/3470496.3527385
paper_keyword: Load Queue; Store Queue; Atomics; Memory Consistency
paper_year: ISCA 2022
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Free Atomics, a microarchitecture optimization aiming at reducing memory barrier cost of atomic 
operations.
The paper is motivated by the overhead incurred by the two implicit memory barriers surrounding x86 atomic operations.
The paper proposes removing these two barriers, allowing the load-store pair belonging to the atomic operation
to freely speculate and be reordered with regular memory operations, thus reducing the overhead.

