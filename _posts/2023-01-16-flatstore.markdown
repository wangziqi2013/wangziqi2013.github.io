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
improvement in operation throughput especially on write-dominant workloads.


