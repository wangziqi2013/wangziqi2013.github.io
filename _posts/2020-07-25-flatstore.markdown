---
layout: paper-summary
title:  "FlatStore: An Efficient Los-Structured Key-Value Storage Engine for Persistent Memory"
date:   2020-07-25 05:21:00 -0500
categories: paper
paper_title: "FlatStore: An Efficient Los-Structured Key-Value Storage Engine for Persistent Memory"
paper_link: https://dl.acm.org/doi/abs/10.1145/3373376.3378515
paper_keyword: NVM; FlatStore; Log-structured
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes FlatStore, a log-structured key-value store architecture running on byte-addressable NVDIMM, which
features low write amplification. 
The paper identifies a few issues with previously proposed designs. First, these designs often generate extra writes to
the NVM, in addition to persisting keys and values, for various reasons. The paper points out that in a conventional
key-value store where all metadata are kept on the NVM, on each key-value insertion or deletion, both the indexing structure 
and the allocator should be updated to reflect the operation. Even worse, most existing indexing structure and allocators 
are not optimized specifically for NVM. 
