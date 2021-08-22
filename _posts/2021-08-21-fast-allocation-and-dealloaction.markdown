---
layout: paper-summary
title:  "Fast Allocation and Deallocation of Memory Based on Object Lifetimes"
date:   2021-08-21 20:30:00 -0500
categories: paper
paper_title: "Fast Allocation and Deallocation of Memory Based on Object Lifetimes"
paper_link: https://dl.acm.org/doi/10.1002/spe.4380200104
paper_keyword: malloc
paper_year: Software - Practice & Experience, 1990
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents the design and implementation of a simple memory allocator that outperforms previous designs by
taking advantage of object lifetime.
The paper observes that object allocation can be as simple as incrementing a pointer on a stack allocator, while 
object deallocation, while usually non-trivial on such allocators, can be optimized by leveraging bulk object 
deallocation, which is not uncommon in many scenarios, and thus be amortized across objects with the 
same lifetime.

The paper discusses two previous storage management algorithms: First-fit and quick-fit. In first-fit, all free
blocks that are part of the process's address space but not yet allocated for usage are maintained in a single
linked list, called the free list. When an allocation of size k is requested, the allocator searches the free 
list, and allocates the first block in the list whose size is larger than k. The block may also be optionally
broken down into smaller blocks before being allocated to reduce internal fragmentation.
Deallocation requires recursively combining the block being deallocated and its near-by blocks into larger blocks, 
and therefore is expensive, as block locations also need to be tracked.

Quick-fit, on the other hand, maintains a series of free lists based on block sizes. The allocator acquires free pages
from the OS, and breaks these pages down into blocks of different size classes, which are then inserted into the 
free list of the corresponding size class. 
On an allocation request, the requested size is first rounded up to one of the size classes, and then the first
block in the free list of that class is allocated (allocations larger than a threshold is satisfied
by another large block allocator). 
Deallocation is also simpler, as the block is only inserted into the head of the free list.
The paper also noted that both allocation and deallocation of quick-fit can be inlined into the call site, and it
only takes a few instructions in the majority of cases.

This paper argues that, despite the fact that quick-fit is efficient and flexible enough in most of the scenarios, 
it still requires individual objects to be deallocated, which is not only unnecessary in certain cases, but also 
prone to memory leaks, if the programmers forget to free some of the allocated objects.

To further optimizes quick-fit, the paper observes that in many scenarios, the lifetime of objects are often nested,
and objects allocated at different points are deallocated together. For example, in a window system, all control objects
will be deallocated when the window is destroyed; In a compiler implementation, all objects allocated for a scope will 
be deallocated at the end of a scope. 