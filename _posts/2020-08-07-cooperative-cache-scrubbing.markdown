---
layout: paper-summary
title:  "Cooperative Cache Scrubbing"
date:   2020-08-07 21:13:00 -0500
categories: paper
paper_title: "Cooperative Cache Scrubbing"
paper_link: PACT 2014
paper_keyword: Cache; Cache Scrubbing
paper_year: 
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes cooperative cache scrubbing, a technique for reducing cache-memory bandwidth. The paper points out
at the beginning that as computing infrastructures keep scaling up, the energy conssumption of main memory has become
a major part of total energy of the system. Each read and write operation will consume energy and increase heat dissipation. 
The paper observes, however, that not all traffic to and from the main memory are necessary. Some of them can be entirely
avoided given that software can convey extra information about the allocation status of cache lines to hardware. 

The paper identifies two sources of unnecessary memory accesses. First, in object-oriented, garbage collected languages,
small objects are created for common data structures, with many of them having short lifetime, meaning that these 
objects will likely be still in the cache when their memory is garbage collected by the runtime. After garbage collection,
the contents of these objects become irrelevant to the computation since most languages do not specify the behavior of
accessing unallocated memory. These dead objects, if written back to the main memory via cache eviction, will consume
bandwidth and energy, but never read again.
Second, some high-level programming languages guarantee that newly allocated objects are always zero-initialized.
Conventional memory architecture requires that all cached contents be backed by main memory, meaning that when
an object is allocated, its address is always in the physical address space, which must be loaded into the cache first,
if not already, before zero-initialization. The memory read traffic, however, is also unnecessary, since the 
pre-initialization content is never read before they are filled with zeros. 

Ideally, if the cache hierarchy is aware of the life cycle of objects, i.e. which cache lines represent live objects
and which represent dead objects, more flexible decisions can be made to minimize these unnecessary traffic by not
writing back dirty lines of dead objects, and not loading the previous value before initializing a block. In practice,
the runtime library of the language maintains the allocation status of objects. The paper suggests that special
instructions be provided to hardware as a "hint" of object life cycles. In this model, software conveys the status of
objects by marking the corresponding cache lines, and hardware cooperatively evicts or fills the line.

Four special instructions are proposed in this paper: clinvalidate, clundirty, clclean, and clzeroX. All four instructions
are implemented at the LLC level of a multi-processor, and are integrated with the widely used MESI coherence protocol
with only minor modifications. We next discuss each of the four instructions and their implementations.

clinvalidate, as its name suggests, invalidates a given address and eliminates all copies of the address, if they exist,
from the cache hierarchy. This instruction should be executed by the memory manager when the cache line of a freed block
is not expected to be reused in the near future, such that the content of the line is simply discarded without any write
back regardless of its coherence state. When executed, the core should send a message to the LLC, and the LLC invalidates
all copies of the line as if an external invalidation were received at the LLC level. This works equally for both inclusive
and non-inclusive cache hierarchy, since the LLC has to deal with external coherence invalidates in both cases (with a 
snoop filter if latter).

clundirty instruction changes the state of a line from dirty (M state) to not dirty while retaining the exclusive write
permission (E state). Note that this instruction breaks the ownership transfer rule of MESI, since ownership is
implicitly transferred to the main memory from the M state block without an explicit write back. 
