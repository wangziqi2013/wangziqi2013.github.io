---
layout: paper-summary
title:  "Filtering Translation Bandwidth with Virtual Caching"
date:   2018-12-30 23:21:00 -0500
categories: paper
paper_title: "Filtering Translation Bandwidth with Virtual Caching"
paper_link: https://dl.acm.org/citation.cfm?id=3173195
paper_keyword: Virtual Cache; TLB; GPU; Accelerator
paper_year: ASPLOS 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper seeks to reduce GPU's address translation traffic using virtual private caches. Modern GPUs work with
virtual address spaces directly to enhance programmability, as pointer-based data structures such as graphs can be 
transferred and understood without mangling and demangling. Allowing GPUs to access the virtual address space poses a 
problem: How are VAs translated to PAs without messing up with existing virtual memory framework which is tightly coupled
with the microarchitecture of the processor? 

Current design relies on IOMMU to perform address translation. IOMMU sits on the system bus and handles memory requests 
inbound and outbound the I/O devices. The IOMMU is initialized at system startup time with a standalone page table that
maps the VA used by I/O devices to PA with access permissions. In order to perform translation, I/O devices send translation
request packets carrying the VA to the IOMMU, and the latter walks the page table and returns the resulting PA. To accelerate
translation, both the GPU and the IOMMU are equipped with private TLBs. They function exactly as TLB on the processor, that is,
to provide a fast path of translation when the TLB hits and the PA can be generated within a few cycles. The IOMMU also 
has a dedicated page walk cache (PWC) which stores entries of the page table. To further improve the scalability of the design,
the IOMMU page walker is multi-threaded: At most 16 page walks can be active at the same time. 

Despite the IOMMU optimizations on both the throughput and latency of translation, this paper argues that, on common GPU 
workloads, TLB hit rate is still lower than the case of CPU. One direct consequence is that address translation has become a 
major performance bottleneck on modern GPUs. There are several reasons for this. First, the memory access pattern of GPU 
features large scatter and gather operations. Although the GPU memory controller will try its best to coalesce memory 
requests such that they can be fulfilled with the least number of actual requests, the high parallelism of GPU still 
indicate that a large range of virtual pages will be accessed. Second, since the translation bandwidth is severely limited, 
the burst of translation requests are likely to be serialized at IOMMU, causing a non-negligible slowdown. The last reason
is that some GPU workloads, such as graph algorithms, intrinsically have low locality. In the paper, it is claimed that
the TLB hit rate is only around 60%, and many blocks are actually in the cache while the address translation must be 
performed using the slow path. The conclusion is that the degree of parallelism in existing IOMMU designs do not 
match the highly parallel workload and data access pattern in modern GPUs. It is the serialization of requests at IOMMU,
rather than the translation latency, that degrades performance.

The fact that L1 private cache is more effective than the TLB for preserving locality of accesses suggests that virtual
caching alone can be more effective than physical address caching plus a TLB. Since virtual addresses are directly
used to access the cache, address translation is only necessary when there is a cache miss and the memory block must
be fetched using the physical address. We describe the design of virtual cache as follows. The hierarchy is assumed to 
be inclusive consisting of two levels of write-back, write-allocate cache. Each cache block has an address tag, which is the 
virtual address of the block. In addition to the conventional per-block states as in a physical cache, the access 
permission bits must also be part of the block state, since the TLB is absent and permissions must be checked on every 
memory access. To detect synonym, perform cache coherence and support TLB shootdown, the cache hierarchy is extended 
with a mapping structure called the Forward-Backward Table (FBT). The FBT consists of two tables: One Forward Table (FT)
which maps virtual addresses to physical address as an ordinary TLB, and a Backward Table (BT) which maps physical
addresses back to virtual addresses. The FBT must cover all entries in the cache: For every cache block with virtual 
address tag T, there must be an entry mapping to T's physical address in the FT, and one entry mapping some physical 
address to T in the BT. On FT and BT eviction, both the cache and the other table must be checked, and the corresponding
entries must be evicted also if their addresses are covered by the evicted entry. 

The BT stores the mapping from physical addresses to virtual addresses. It is populated when a cache miss is served by 
the IOMMU using the physical address in the response message, where the VA to PA mapping is inserted into the table if
it does not already exist. Note that each entry in the BT covers a 4KB page, which is larger than the granularity of 
data fetching from the IOMMU which is 64 bytes. To fill this gap, the BT entry also has a bit vector indicating which 
lines within the page are present in the cache. In the previous case, if the VA to PA entry already exists in BT, 
but the corresponding bit is unset, then the bit will be set.

The FT, on the other hand, maps a VA to an entry index of BT. Given a virtual address, the FT could perform a 
local address translation by querying BT for the physical address. In this prespective, the FT can be thought of 
as a lightweight TLB whose content fully covers the cache. The FT will be used when the cache responds to coherence
requests with virtual addresses. In this case a local address translation is necessary since cache coherence 
generally use physical addresses.

Synonym may occur in a virtual address cache as a consequence of multiple VAs mapping to the same PA. Without proper 
handling, multiple copies of the same data will be present in different blocks of the cache, each being potentially 
incoherent with the rest. It is therefore important to enforce the rule that only one copy of the same physical address 
can reside in the cache even if different VAs are used to access the block. In our case we use BT to perform disambiguation 
as follows. When the IOMMU replies to a data fetch request, it tags the data with the PA where it is fetched from.
We have described the scenario in the case that the PA has not yet existed in the BT or the bit is not set and do not 
elaborate here. In the opposite, if there is already an entry in BT and the bit is set, then we know synonym must have 
occurred, because the request must have been issued with a different VA than the current VA tag in the cache (otherwise 
the request will hit the cache and no request is issued). In this case, the access is restarted using the VA recorded 
in the BT, and no new block will be inserted into the cache. Note that although the permission bits might differ
between the current entry in the cache and the actual VA used to access the block, it is generally correct if the 
current permissions are more relaxed than the permission on the actual VA, because the IOMMU will also check for 
permission when the request is being processed. If the permission is violated, an interrupt will be delivered to the 
CPU. **It can be problematic, however, that if the permission of the current cache entry is more restrictive than 
the permission of the VA used to access the block, an otherwise-normal access will be wrongly marked as illegal,
and the program would terminate unexpectedly**. This paper did not figure this out and hence no solution is given.
One quick patch is to ignore the permission bits in the virtual cache entry, since permission check has already
been done by the IOMMU and the access is guaranteed to be legal.

When coherence requests hit the GPU, they are first delivered to the BT to perform a PA to VA translation. The bit 
vector must be checked to see if the cache line actually is in the cache. Coherence actions are taken as usual
using the VA after the first translation. If the cache needs to reply to the coherence message, then the FT
should also be consulted to translate back the VA from the cache to PA which is understandable by the coherence protocol.
Also note that in this case, the cache actually handles less coherence traffic, as the BT effectively serves as a 
traffic filter for coherence requests.

When a TLB shootdown request is received, the cache hierarchy must not only flush the corresponding entries from the 
FT, but also flushs the cache. The latter is not required for a physical address cache, since mapping changes have 
nothing to do with the actual content of memory. The TLB shootdown request is handled as follows. First the FT is 
locked, and no new memory requests are allowed. Next the cache controller waits for all outstanding memory requests to 
be drained before it can proceed. Then the cache controller walks the cache tag array, and invalidate cache lines
covered by the shootdown request. After that the FT is unlocked, and memory operations could resume.