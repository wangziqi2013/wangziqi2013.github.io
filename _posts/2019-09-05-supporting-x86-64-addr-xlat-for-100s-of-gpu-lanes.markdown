---
layout: paper-summary
title:  "Supporting x86-64 Address Translation for 100s of GPU Lanes"
date:   2019-09-05 20:49:00 -0500
categories: paper
paper_title: "Supporting x86-64 Address Translation for 100s of GPU Lanes"
paper_link: Supporting x86-64 Address Translation for 100s of GPU Lanes
paper_keyword: GPU; Paging; TLB; Virtual Memory
paper_year: HPCA 2014
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper explores the design choice of equipping GPUs with a memory manegement unit (MMU) in order for them to access
memory with virtual addresses. Allowing GPU and CPU to co-exist under the same virtual address space is critical to
the performance of GPU applications for future big-data workloads for several reasons. First, if the GPU can share storage
with CPU, data does not need to be copied to dedicated GPU memory before and after the task, which implies lower bandwidth
requirement, energy consumption and latency.