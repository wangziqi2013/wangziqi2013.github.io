---
layout: paper-summary
title:  "Translation-Triggered Prefetching"
date:   2019-01-05 23:59:00 -0500
categories: paper
paper_title: "Translation-Triggered Prefetching"
paper_link: https://dl.acm.org/citation.cfm?id=3037705
paper_keyword: TLB; Prefetching; DRAM
paper_year: ASPLOS 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes TEMPO, an automatic prefetching scheme driven by TLB misses. Modern big-data workloads, unlike classical
scientific computation, demonstrates less locality and hence exhibits higher TLB misses. There are several causes of decreased
locality, such as graph workloads where nodes are linked by pointers; sparse data structures where non-adjacent entries are 
stored in noncontiguous blocks of memory, and large memory workloads where the amount of translation information is just too
large to be cached entirely in the TLB, causing TLB thrashing. When TLB miss happens, the page walker must load the PTE entry from
the main memory into TLB, and then replay the memory access instruction, which will hit the TLB. One important observation made
by the paper is that a large fraction of TLB misses are actually followed by cache misses. This is because TLB misses are often
indicators of the fact that the target physical address is cold and has not been touched for a while. In such cases, it is
reasonable to expect that the cache does not contain the target block.

Based on this observation, TEMPO attempts to mitigate the "double miss" problem by prefetching the target memory address when
the last level TLB entry is read from the DRAM. The approach is described as follows. When a TLB miss is detected, the page walker
initiates the page walk process. The page walk is unchanged for all levels expect the last one. When the page walker reaches the 
last level of the page table (we assume a x86-64 multi-level page table), the physical address of the block that will be 
fetched shortly is known, and hence the target address can be prefetched to overlap DRAM access with TLB miss handling. 
The page walker injects the memory request for the last level page table entry (PTE) with two more fields. One is a special
flag indicating that the DRAM read request is for the last level PTE. Another is the cache line address within the physical 
page, which can be generated from the virtual address and only consists of 6 bits given 4KB page and 64 byte cache line.
Once the request is received by the memory controller, the controller schedules two requests in its transaction queue.
The first request is the one that reads the PTE. The second request reads the target address, and special processing is needed,
since the target address is not known until the first request is processed. After the DRAM controller completes the request for 
PTE, it notes down the physical address (since the format of the PTE is known), and then proceeds to read the target block
using the physical address and the cache line offset. After the cache line is also read, the memory controller sends 
a response message back to the cache controller, and the cache controller fills the LLC with the line just read.
The memory request is replayed as usual, and if it misses the first few cache levels in the hierarchy, the prefetched line
can be provided by the LLC.

With memory requests for last level PTE explicitly marked, a few other optimizations also apply. One example is to schedule 
multiple accesses to the same DRAM row into one request. This is realized as follows. In DRAM, the row buffer is used to latch
the data read from capacitors which do not directly provide stable and readable digital. If two consecutive requests access
different rows, the row buffer must be written back to the row, before the next row can be fetched. The write back process 
is called "precharge", and adds an extra overhead to memory accesses if the locality is poor. If, however, two accesses use
the same row, then the row buffer can be repeatedly read without any precharge. Taking advantage of this, the memory controller
does the following: If there are multiple last level PTE requests in the transaction queue, and the target address of the 
PTE are within the same row buffer, the memory controller schedules these two requests together, ensuring that their
accesses hit the same row. There are two obvious benefits: First, since TLB misses and the potential cache miss are often
the bottleneck of memory operations, prioritizing TLB misses and the following prefetching can improve instruction throughput. 
Second, in workloads where consecutive pages are scanned, it is common that multiple TLB misses are on-the-fly and hence 
can be combined by the memory controller into one request to the DRAM row. Instead of performing two expensive precharge 
operations, only one such operation is needed, improving the throughput of DRAM also.  