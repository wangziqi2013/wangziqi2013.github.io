---
layout: paper-summary
title:  "Lossless and Lossy Memory I/O Link Compression for Improving Performance of GPGPU Workloads"
date:   2020-07-19 20:01:00 -0500
categories: paper
paper_title: "Lossless and Lossy Memory I/O Link Compression for Improving Performance of GPGPU Workloads"
paper_link: https://dl.acm.org/doi/10.1145/2370816.2370864
paper_keyword: Compression; Memory Compression; GPGPU; Floating Number Compression
paper_year: PACT 2012
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes adding memory compression to GPGPU memory architecture for improving performance with reduced bandwidth 
consumption. Although many previous publications focus on saving storage and providing larger effective memory, this paper
explores another aspect of memory compression: Saving memory bandwidth for memory-bound GPGPU workloads. The paper points
out that GPU workloads often have better compressibility than CPU workloads for two reasons. First, GPGPUs are designed
to process input data in a massively parallel manner, with the same "kernel". The input data, therefore, is usually 
arrays of integers or floating point numbers of the same type, which can be easily compressed. In addition, real-world
workloads observe high degrees of locality, further enabling highly efficient compression.
