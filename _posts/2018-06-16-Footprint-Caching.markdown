---
layout: paper-summary
title:  "Efficient Footprint Caching for Tagless DRAM Caches"
date:   2018-06-16 00:00:00 -0500
categories: paper
paper_title: "Efficient Footprint Caching for Tagless DRAM Caches"
paper_link: https://ieeexplore.ieee.org/document/7446068/
paper_keyword: cTLB; DRAM cache; tagless; footprint caching; over-fetching
paper_year: HPCA 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper extends the idea of Tagless DRAM Cache, and aims at solving the over-fetching
problem when main memory is cached in page granularity. The over-fetching problem states that
if the locality of memory accesses inside a page is low, the bandwidth requirement and latency for 
bringing the entire page into L4 cache cannot be justified by the extra benefit it introduces. Footprint 
caching, on the other hand, transfers data at 64 byte cache line guanularity and lazily fetches only cache 
lines that are accessed. The frequently accessed cache lines in a page are recorded as the metadata
of the page in the page table when the cache block is evicted. The next time the page is fetched from the main 
memory due to a cache miss, only the frequently accessed lines will be transfered. Footprint caching maintains 
a high hit rate while reduces the bandwidth requirement of ordinary page based caching. In the following sections
we will present a design in which footprint caching is integrated into tagless DRAM cache in order to 
solve the over-fetching problem.

Tagless DRAM cache emerges as on-die DRAM now becomes available on commercial hardware. On-die DRAM
typically has lower access latency compared with the main memory DRAM, but has less capacity. To make the 
best use of it without overburdening the OS with complicated memory allocation and scheduling problem, hardware 
designers have proposed to dedicate the extra hundreds MBs or even few GBs of storage to serving as an L4 cache. 
The challenge, however, is that if DRAM caches are to be organized just like the SRAM cache, the storage 
for the tag array would be tens of MBs in size, which is not feasible to be implemented on-chip. One of the solutions
that is relevant to our topic is the *tagless DRAM* design, where the L4 cache does not use tags to identify blocks.
Instead, the TLB is extended with a "cache address" field, in which the location of the block in the DRAM cache 
can be located using this pointer. Caching is always performed on page granularity. The system maintains an 
invariant that as long as a TLB entry is valid, the corresponding page must be cached in L4. On a TLB miss, the 
page walker not only finds and loads the physical address from the PTE, but also checks the PTE to find out 
whether the page has already been cached by L4. If not, one entry in L4 is allocated, and the entire page is 
brought into the DRAM cache. The PTE is extended with three extra bits: VC bit to indicate whether the page 
has already been cached; NC bit to indicate whether the page is cachable; PU bit as a spin lock to serialize
page walkers from different cache controllers. Furthermore, if the VC bit is turned on, which indicates that
the page is already in L4, the physical address in the PTE is replaced by the cache address. This avoids multiple 
redundant copies of a single page by different page walkers. Besides that, a global inverted page table (GIPT)
is added to map cache blocks to the physical pointer of its main memory copy, the pointer to its PTE, and a bit vector
to indicate which TLBs in the system has an active entry for this block. The GIPT also has a free queue that holds 
the cache address of blocks that are to be evicted back to the main memory. A background hardware state machine 
performs write back and updates the PTE using information stored in GIPT. All free blocks in the L4 cache are 
chained together using a free list, the head pointer of which is also maintained as part of the GIPT. Both GIPT
and the L4 cache are shared by all cores.

Footprint caching decouples cache block allocation from cache block filling. In the original proposal, over-fetching
would occur if a segment is fetched into the 4 KB block, but is never accessed before the block is evicted.
The over-fetching problem can be alleviated by allowing data be to fetched at sub-page granularity on-demand. Two bit 
vectors are added into both the TLB and the PTE to support this: A valid bit vector to indicate whether a 64 byte segment 
is valid in the cache, and a reference bit vector to record the segments that are filled on-demand after the block is 
allocated in the cache. Note that the reference bit vector is not always a subset of valid bit vector, because if a block
is evicted, then all of its valid bits are cleared. In the paper, the size of both bit vectors are 8 bits. 

The modified scheme is called F-TDC (Footprint-Tagless DRAM Cache), and it operates as follows. On a TLB hit, the cache 
controller checks the valid bit vector for the corresponding segment. If the bit is set, then the L4 is accessed using
the cache address. Otherwise, the page is allocated in the cache, but the segment has not been filled yet. In this case, 
the hardware page walker uses GIPT to load the segment into L4, and updates the reference bit vector for TLB, and valid 
vector for TLB as well as the PTE.

If the TLB misses, then the page walker is invoked to find the PTE. If the PTE has a non-zero valid bit vector, then 
the page walker directly loads the TLB with the cache address stored in the PTE. The valid bit vector is also loaded.
If the segment accessed by the instruction is not valid, the page walker also initiates a transfer from the main
memory, after which the bit vectors are updated as in the previous case.

If TLB misses, and the PTE has all-zero in its valid bit vector, then the block is also not in the cache. In this case,
the page walker allocates a block in L4, updates the GIPT, and fills the block with only segments that has reference bit
set in the PTE. The physical address field of the PTE is replaced with the allocated cache address as in TDC.

On a TLB eviction, both the reference bit vector and valid bit vector should be written back to the PTE entry. In a multicore
environment, however, although the paper mentions that writing back bit vectors is necessary, I doubt whether this is truly 
the case, as the PTE must always be maintained consistently with the TLB. This requirement is different from classical cache 
coherence problem, because we did not assume a TLB-to-TLB transfer of valid bits. Since valid bits must always be obtained from
the PTE even if some TLBs in the system have a copy. Given this constraint, Whenever a bit is set in the valid bit vector,
a coherence message must be sent among all TLBs in the system to update the status of the segment in other TLBs, as well as 
the bit vector in the PTE. The coherence mechanism is similar to hardware cache coherence, and it is broadcasted using the 
cache coherence network. As pointed out by the paper, since changing the valid bit should be a relative rare event, the 
broadcasting is expected to have small overhead. The reference bits, on the other hand, do not need to be kept consistently 
among all cores. They can be merged back into the PTE as TLB entries are evicted.
