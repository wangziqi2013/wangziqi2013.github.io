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

**Highlights:**

1. Combines stack allocation, which is difficult to free objects unless their lifetimes are perfected nested, with
   per-lifetime stack allocator, which clusters objects with the same deadline. 
   This way, stack allocation works better because we can dispatch allocations of different deadlines to 
   different instances of the stack allocators, such that the object lifetime on a single stack allocator 
   are perfectly nested.

**Comments:**

1. The term "lifetime" may not be accurate. A better word is "deadline", i.e., the proposed algorithm clusters
   objects of the same deadline (not necessarily the same lifetime because they can be allocated at different
   contexts) for batch deallocation and amortized deallocation cost.

2. There is a corner case where the allocation size exceeds the arena size. 
   The next arena should be allocated as a bigger block than the requested size, rather than using the pre-determined 
   size, because otherwise the allocation will never be satisfied.
   The paper uses INCR*1024 as arena's allocation size, which is incorrect.

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

To further optimize quick-fit, the paper observes that in many scenarios, the lifetime of objects are often clustered,
and objects allocated at different points are deallocated together. For example, in a window system, all control objects
will be deallocated when the window is destroyed; In a compiler implementation, all objects allocated for a scope will 
be deallocated at the end of a scope. 
This can be leveraged by having multiple stack allocators, and dispatch object allocation requests to one of the 
stack allocators based on the object's lifetime, i.e., objects with the same deallocation point are allocated from
the same stack allocator, and destroyed in batches. 
This has two obvious advantages. First, stack allocators are as efficient as quick-first free lists, if not more 
efficient. Second, stack allocators support constant time deallocation of all objects on the stack by just resetting
the allocation pointer. This is a great advantage over quick-fit, which has linear-time deallocation.

We next describe the details of the design as follows. At allocation time, programmers need to provide both the 
allocation size, and the lifetime information indicated by an integer. Different integers represent different
lifetime, and the numeric values of these integers have nothing to do with the actual lifetime. 
The allocator maintains a few stack allocators, one for each possible lifetime.
Allocation requests of size k with lifetime x is translated to an allocation request of size k at stack allocator 
instance x. 
Each stack allocator consists of a series of memory blocks called arenas. Each arena is just a continuous chunk of 
memory that is allocated as a stack, the current allocation point of which is indicated by a "top" pointer. 
The allocator maintains a per-lifetime arena pointer that points to the current active arena for serving requests.
On an allocation request, if the requested size can be satisfied within the current arena, the top pointer is 
incremented by the requested size, before the pre-value of the pointer is returned.
Otherwise, a new arena is allocated (the size of the arena needs to be at least the requested size), and the 
allocation is reattempted on the new arena. This process is constant time, since at most two arena
allocation and one allocation from the OS are performed.
Arenas of the same lifetime are organized into linked lists for reuse, as we will see later.

Deallocation happens at a larger granularity of entire lifetimes. Programmers can only deallocate all objects in
a per-lifetime allocator by indicating the integer identifier of the lifetime. 
Deallocation works by simply resetting the per-lifetime pointer to the first arena in the list.

