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
are not optimized specifically for NVM. For example, for B+Tree structures, a leaf node insertion involves shifting 
existing elements to maintain the sorted property; Similar overheads exist for hash tables, where rehashing or element
relocation is required when the load factor exceeds a certain threshold.
Second, many designs are incorrectly optimized with techniques such log-structured storage. These optimizations may work
well for conventional disks or SSDs, but are incompatible with NVDIMM. The paper points out two empirical evidences that 
may affect the design.
First, repeated cache line flushes on the same address will suffer extra delay, discouraging in-line updating of NVM
data. This phenomenon becomes even more dire given that the access pattern is usually skewed towards a few frequently
accessed keys, further aggravating the latency problem.
The second observation is that the peak write bandwidth is achieved when the write size equals the
size of the internal buffer (256 bytes), and remains stable thereafter when multiple threads write into the same device 
in parallel. One of the implications is that writing logs in a larger granularity than 256 bytes will not result in
higher performance, contradicting common beliefs that the larger the logging granularty is, the better performance it 
will bring. Larger logging granularities, however, negatively impact the latency of operation, since an operation
is declared as committed only after its changes are persisted with the log entries.

FlatStore overcomes the above issues with a combination of techniques as we discuss below. First, FlatStore adopts the
log-structured update design to avoid inline updates of data, converting most data updates to sequential writes.
In addition, log entries are flushed frequently in 256 byte granularity to minimize operation latency. To support
small log entries, FlatStore uses two distinct log formats. If the key and value pair is sufficiently small to be contained
in a log entry, then they will be written as inline data within the entry. Otherwise, the log entry contains pointers
to the key and value, which are stored in memory blocks allocated from the persistent heap.
Second,