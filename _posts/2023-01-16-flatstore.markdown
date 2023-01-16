---
layout: paper-summary
title:  "FlatStore: An Efficient Log-Structured Key-Value Storage Engine for Persistent Memory"
date:   2023-01-16 03:35:00 -0500
categories: paper
paper_title: "FlatStore: An Efficient Log-Structured Key-Value Storage Engine for Persistent Memory"
paper_link: https://dl.acm.org/doi/abs/10.1145/3373376.3378515
paper_keyword: NVM; FlatStore; Key-Value Store; Log-Structured
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes FlatStore, a log-structured key-value store designed for NVM. FlatStore addresses the bandwidth
under-utilization problem in prior works and addresses the issue with careful examination of NVM performance 
characteristics and clever designs on the logging protocol. Compared with prior works, FlatStore achieves considerable 
improvement in operation throughput, especially on write-dominant workloads.

FlatStore is, in its essence, a log-structured storage architecture where modifications to existing data items 
(represented as key-value pairs) are implemented as appending to a persistent log as new data. In order for read
operations to locate the most recent key-value pair, an index structure keeps track of the most up-to-date value given
a lookup key, which is updated every time to point to the newly inserted key-value pair every time a modification
operation updates the value. Compared with conventional approaches that update data in place, a log-structured
key-value store transforms random writes to updated values to sequential writes at the end of the log buffer
and therefore demonstrates better write performance. Besides, the atomicity of operations can be easily guaranteed
because the update operation is only committed when the corresponding index entry is updated.

Despite being advantageous over the conventional designs, the paper noted, however, that prior works on log-structured
key-value stores severely under-utilize the available bandwidth of NVM, often falling behind to only using one-tenth
of the raw bandwidth. After careful investigation, the paper concludes that prior designs fail to utilize the full
bandwidth for two reasons. First, these designs keep the index structure in persistent memory which will be read
and written during operations. 

The paper also observes a new trend in key-value workloads on production systems. First, most values are small, with
the size of the majority of objects being inserted fewer than a few hundred bytes. Secondly, today's workloads 
exhibit more fast-changing objects, indicating that these workloads are likely write-dominant. The paper hence concludes
that an efficient key-value store design should be specifically optimized to support small objects well and should be 
writer-friendly.
