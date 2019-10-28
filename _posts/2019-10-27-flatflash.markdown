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
mmap(). On a memory access, the MMU will first translate the virtual address to the physical address and probe the cache
as usual, and if there is a cache miss, the memory request will be sent to the memory bus. On seeing this request,
the PCIe controller will check whether the address is in the MMIO range, and if positive, the request will be forwarded
to the corresponding device. 

On seeing the forwarded memory request from the memory bus, the SSD controller will begin a transaction to read or 
write the indicated address. One difficulty in the design is that SSDs can only be accessed in block granularity,
and the access speed is usually slower than DRAM. To solve this problem, FlatFlash proposes that the SSD dedicate
its internal DRAM as a page cache holding recently accessed pages from the SSD. As a ressult, the SSD memory,
which is intended to be used as a storage for Flash Translation Layer (FTL) and other functions, can no longer serve
their original purposes. The paper suggests that the OS now should act as a FTL which translates linear physical address
to SSD internal physical addresses (which consists of indices of storage arrays at each level of the internal
hierarchy), which is then sent via the memory request to the SSD. On completion of the memory request, the SSD sends
a PICe response message back to the processor, which contains 64 bytes of cache line data. 

The page cache on SSD is organized as a conventional set-associative cache. The paper suggests that the cache should use
RRIP as the replacement poloicy, due to the fact that RRIP performs better when the access pattern is more random, which 
is the norm for lower level storage in the hierarchy as locality has been filtered out by upper levels. 

One of the most important feature of FlatFlash is page promotion, which migrates frequently accessed "hot" pages from the 
page cache to the DRAM which is closer to the processor. Page promotion is initiated by the I/O controller on the processor 
side, which maintains an access count for each cache line sized block in the page cache. The paper proposes an algorithm 
for determining which page to promote and for updating page access counters in the event of accesses, evictions and 
promotions. After the promotion decision has been made, the I/O controller begins to read out the content of the page 
in cache line granularity (i.e. the same as normal memory read), and stores them into a free page allocated by the OS.
To avoid race conditions during the promotion with concurrent memory accesses, the paper proposes adding a "Promotion
Lookaside Buffer" (PLB) to store the progress of the promotion. In the PLB, an entry consists of a valid bit, a page 
address tag, and a bitvector for every cache line in the page. When the promotion starts, the I/O controller inserts an 
entry into the PLB and clears the bitvector. It then begins to read out cache lines and fills the DRAM page. After the 
page is written, the corresponding bit is set. The race condition occurs when an evicted cache line is written back to
the SSD while the cache line is being migrated. If care is not taken, the content of this dirty line might be lost.
To solve this problem, the I/O controller also monitors cache write backs from the LLC. If the address of the line
matches one of the entries in the PLB, then the line will be redirected to the DRAM page address, and the bit is set.
On the other hand, a set bit in the bitvector also indicates to the I/O controller that the line should not be copied 
over from the SSD. The entry is removed after all lines are copied. The I/O controller also modifies the page table such
that future accesses are redirected to the DRAM page. 

Garbage collection in FlatFlash is performed in page granularity as well. When a dirty page is written back, the SSD block
(which is the unit of erasure) that contains the page is read out to an internal buffer, and the page is merged into the 
block. The modified block is then written to a new block. The mapping in the page table also needs to be modified accordingly
by the garbage collector, since the page table maintains the internal hardware address for the SSD.