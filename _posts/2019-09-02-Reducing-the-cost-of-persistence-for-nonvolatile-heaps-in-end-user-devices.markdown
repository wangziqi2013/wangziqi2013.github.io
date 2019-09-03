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
ensuring correctness). The paper gives an example: When a persistent hash table co-exists with other NVMCap applications,
these NVMCap applications observe higher cache miss rates, ranging from 2% to 25% more. Even worse, on a multicore platform,
where NVMCap and NVMPersist applications are scheduled on different cores which execute on disjoint caches, if a cache line
is shared by multiple caches, the flush instruction will have to invalidate all copies in the cache hierarchy, which itself
is a global operation that would take many cycles to complete.

**Note: This paper does not give any explanation of what is "cache sharing" (I think it is way-sharing in the same set)
and similarly no explanation on what causes the higher miss rate. What's the difference between these two types of 
applications and any two applications that share the same LLC?**

**Note 2: I guess the paper is trying to say that since NVMPersist cache lines will be flushed anyway shortly after they 
are written, these short-lived cache lines should not cause other cache lines to be evicted just because it needs the
cache.**

The second problem is metadata overhead of memory allocators. Previous NVM-based allocators store their metadata on the 
NVM directly, which is updated every time an allocation request is fulfilled. Given that modern memory allocators have fairly
complicated internal states and policies, this will incur large amount of data being written to the NVM on every memory
allocation, which also stays on the critical path. Furthermore, in order for NVM objects to be found after a crash or reboot,
non-volatile objects themselves are also associated with metadata, such as a string as the object's name, or the CRC code
to verify integrity of the object. Such object metadata should also be written back to the NVM as part of the allocation process. 

The third problem is logging which is widely used as the method for providing atomicity and durability to persistent 
transactions. This paper assumes a redo logging approach, but the same principle applies to undo logging. Currently, two
flavors of logging are used by various schemes. The first approach, word-based logging, simply records every memory modification
at word granularity and writes a log record. The problem, however, has a metadata overhead of more than 50%, which means that
more than half of NVM storage is dedicated to storing the address tag and other status bits instead of logged data. The second
approach, object-based logging, treats a predefined object as an indivisible logging unit. The entire redo image of the 
object is copied to the log with one address tag indicating the base address of the object. This way, only very few metadata
records are written compared with the amount of logged data. The problem with this approach is that if the objects are 
large and modifications are small, space will be wasted storing the unmodified part of the object.

To solve the cache sharing proble, the paper levarages an architectural knowledge that continuous cache lines are typically
mapped to different sets in the cache in most cache implementations. The paper suggests that the physical pages allocated
to a process should be made contiguous as much as possible, such that the cache lines of the applications are evenly distributed 
within all cache sets, rather than biased towards a few sets and content for cache slots with NVMCap applications. Based on this
observation, the paper proposes modifying the OS's page allocator as follows. For each process in the system, the OS maintains
a bucket of contiguous pages for the process. The bucket is initially empty. Whenever a page is allocated for the process, the OS
reserves a range of physical pages around the allocated page (based on page availbility) and adds them into the bucket. The
next time the same process requests a page, the OS can simply allocate from the bucket, maintaining a contiguous physical
page map as much as possible. Inevitably, reserving pages on allocation will result in external fragmentation, i.e. some
processes may not be able to find contiguous pages when it allocates a page. The OS maintains two watermarks to determine 
when this allocation policy should be used. If the amount of memory is low, the OS begins allocating non-contiguous pages
to NVMPersist applications. When the system is close to out of memory, the OS disables this policy and frees all pages 
back to the physical page pool.

To solve the second problem, the paper proposes that only essential metadata is logged while other complicated data
structure remain in the DRAM as usual. Essential metadata for a memory allocator includes the physical address map and virtual
address map. The physical address map records which ranges of physical addresses are occupied by active objects, and the 
virtual address map stores the mapping between virtual address ranges and named objects. Note that the virtual address
map is critical for NVM applications, due to the fact pointer values are virtual addresses. Pointers must still point
to the same object as before the crash or reboot. When a memory allocation request is fulfilled, the allocator logs the 
changes to the virtual and physical address map, and write a log record to a dedicated allocator logging area. This 
logging area is on a known location and can be used to rebuild the memory map (including page table and physical memory
map) by replaying the allocation log (free and alloc cancel out). Internal states of the allocators can be rebuilt by
software logic after the map is recovered.

To solve the last problem, the paper proposes hybird logging which enables both word level and object level logging.
The library provides two different interfaces to allow programmers to choose from. The paper also proposes storing 
log data and log metadata in two different segments to accelerate log entry iteration, since for object logging the 
size of the object being logged can vary radically. 