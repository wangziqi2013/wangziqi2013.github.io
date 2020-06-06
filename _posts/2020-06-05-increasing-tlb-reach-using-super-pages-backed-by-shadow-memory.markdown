---
layout: paper-summary
title:  "Increasing TLB Reach Using Superpages Backed by Shadow Memory"
date:   2020-06-05 16:15:00 -0500
categories: paper
paper_title: "Increasing TLB Reach Using Superpages Backed by Shadow Memory"
paper_link: https://dl.acm.org/doi/10.1145/279361.279388
paper_keyword: Virtual Memory; Shadow Memory; Huge Page
paper_year: 
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes MTLB, a memory controller based TLB design aimed at extending the reach of conventional in-core TLBs.
The paper points out that conventional TLB design with standard 4KB - 8KB pages is not sufficient for achieving high
performance on modern hardware, since the reach of the TLB is only a few hundred KBs, while the first-level cache in
the system can easily exceed several MB in capacity (at the time of writing). With large working sets whose size exceeds 
the reach of the TLB, the TLB can become a bottleneck because of frequent TLB misses and page walks.


