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
operation updates the value. 
