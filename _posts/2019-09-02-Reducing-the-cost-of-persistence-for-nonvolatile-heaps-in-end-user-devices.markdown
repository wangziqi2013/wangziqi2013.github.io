---
layout: paper-summary
title:  "Reducing the Cost of Persistence for Nonvolatile Heaps in End User Devices"
date:   2019-09-02 20:04:00 -0500
categories: paper
paper_title: "Reducing the Cost of Persistence for Nonvolatile Heaps in End User Devices"
paper_link: 
paper_keyword: NVM; Page Coloring; Logging
paper_year: HPCA 2014
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper identifies three problems with NVM applications on mobile platforms and manages to solve these problems
with software-only approaches. Applications running on the NVM are classified into two categories. The first category
of application, called NVMCap by the paper, only uses the NVM as an extra chunk of memory, the content of which is 
no longer needed after a crash or system reboot. These applications include those whose use the NVM as a video buffer
or a swap area. The second category is called NVMPersist, which rely on NVM's ability to retain the content of 
application data after a crash or reboot. Examples of such applications are background database services that maintain
user session and profile data. In practice, these two types of applications often co-exist on the same 
mobile platform, which can introduce subtle problems, either by their own, or because of the subtle interactions
between them. 

This paper assumes that the NVM device is directly attached to the memory bus, whose storage is exposed to the operating
system as a byte-addressable memory. The paper recommends that the NVM device be mapped into the address space and managed 
by the OS as a persistent heap, rather than using block I/O which adds another level of indirection and makes software
the major bottleneck on the critical path. Applications request for memory allocation via special interfaces provided by
the library. Different libraries calls are provided for NVMCap and NVMPersist applications to allocate memory, in order
to achieve better overall storage management. Since DRAM is relatively precious resource on mobile platform, this paper 
assumes no presence of DRAM cache as temporary store to evicted NVM data.

The paper identifies three problems with a mobile platform running both NVMCap and NVMPersist applications. The first 
problem is cache sharing. As NVMPersist applications must regularly flush back dirty data to enure persistence, frequently used
cache lines by NVMCap applications are expected to be invalidated often by the cache flush logic. This, however, is detrimental
if NVMCap applications store its run time data in the same cache line, creating false sharing. These applications will observe
higher than usual cache miss rates, even if they do not issue cache line flush instructions (nor are they needed for 
ensuring correctness). The paper gives an example