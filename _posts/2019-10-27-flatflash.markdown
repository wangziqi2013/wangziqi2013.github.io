---
layout: paper-summary
title:  "FlatFlash: Exploiting the Byte-Addressibility of SSDs within a Unified Memory-Storage Hierarchy"
date:   2019-10-27 22:12:00 -0500
categories: paper
paper_title: "FlatFlash: Exploiting the Byte-Addressibility of SSDs within a Unified Memory-Storage Hierarchy"
paper_link: https://dl.acm.org/citation.cfm?doid=3297858.3304061
paper_keyword: SSD; Virtual Memory; FlatFlash
paper_year: ASPLOS 2019
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes FlatFlash, an architecture that allows SSDs to be connected to the memory bus and used as 
byte-addressable memory devices. While the size of big data workloads keep scaling, the capacity of DRAM based memory 
in a system cannot grow as fast as the size of the workload. Current solutions for solving the memory scarcity problem
is to use SSDs as backup storage accessed in block granularity, leveraging the address mapping and protection capability 
of virtual memory. This solution, however, has several problems. First, in virtual memory scheme, unmapped addresses 
are mapped as inaccessible pages. When such addresses are accessed by memory instructions, the system will trap into
the OS kernel, which then reads the page from the SSD, and swaps out the current page. This process involves an
OS conducted address translation, one read and one write I/O, and one TLB shootdown (this can be avoided if the shootdown
is performed lazily, i.e. we wait until the next time another core traps into the kernel by using the stale entry in
its local TLB, at the cost of more mode switches), which is rather expensive. The second problem is that if the working
set size is larger than available amount of DRAM, then page swaps will be consistly trigger due to accesses to non-present
pages, causing thrashing. This greatly reduces system efficiency as the overhead of swapping pages will quickly saturate 
the system. The last problem is that for data with little or none locality, bringing an entire page into the DRAM
is a waste on I/O bandwidth, since only a small portion of the page will be accessed before the page is evicted.

FlatFlash solves the first two problems by directly connecting the SSD to the memory bus via PCIe. The PCIe standard supports
memory mapped I/O (MMIO) by providing six Base Address Registers (BAR) for each device. These BARs can be configured at
system boot time, such that the internal storage of the device can be mapped to a certain memory region. (The paper 
did not specify whether the SSD BAR indicates virtual or physical address, and I am not familiar with this aspect,
so I assume that it is physical address, and that the memory controller could identify this address and sends the 
request to the PICe bridge). Once the SSD is mapped to the physical address space of the processor, both the OS and user 
programs could access this portion of the physical address via OS-controller virtual address mapping, e.g. by calling 
mmap(). 