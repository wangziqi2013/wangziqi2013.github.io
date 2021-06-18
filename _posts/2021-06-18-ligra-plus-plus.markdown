---
layout: paper-summary
title:  "Smaller and Faster: Parallel Processing of Compressed Graphs with Ligra++"
date:   2021-06-18 01:00:00 -0500
categories: paper
paper_title: "Smaller and Faster: Parallel Processing of Compressed Graphs with Ligra++"
paper_link: https://ieeexplore.ieee.org/document/7149297
paper_keyword: Compression; Graph Compression; Ligra++
paper_year: DCC 2015
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents Ligra++, a compressed graph library based on Ligra.
Despite the fact that graph compression has been attempted from multiple directions, the paper points out that it is
still an interesting topic that is worth studying for two reasons. 
First, as more and more computation tasks nowadays have been moved to the cloud, it becomes crucial to reduce the 
memory footprint of these tasks, as cloud platforms often charge customers by the amount of memory consumed on the 
computing node.
Second, previous proposals often only consider sequential graph algorithms, missing the opportunity of parallelization.
Ligra++, on the contrary, is designed for parallel computation on the compressed graph.
The paper also noted that, since graph computation is memory bound, compression helps reducing the memory bandwidth
required to fetch the same amount of information from the memory to the cache hierarchy. 
As a result, more parallelism can be extracted. In addition, since for most of the time, the processor will be 
waiting for cache misses rather than executing arithmetic instructions, the paper argues that the increased number 
of instructions for runtime decoding will likely not become a significant factor to performance.