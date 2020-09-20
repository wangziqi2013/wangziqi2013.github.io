---
layout: paper-summary
title:  "Cooperative Cache Scrubbing"
date:   2020-08-07 21:13:00 -0500
categories: paper
paper_title: "Cooperative Cache Scrubbing"
paper_link: https://dl.acm.org/doi/10.1145/2628071.2628083
paper_keyword: Cache; Cache Scrubbing
paper_year: PACT 2014
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Rely on language runtime to convey life cycle information of objects to the hardware

2. Take advantage of the observation that dirty lines of dead objects need not be written back to the main memory since
   they will never be accessed again for read. Also, zero-filled lines do not need to be read from the main memory, since
   the old content will never be read before overwritten with zeros. 
   These two, if combined together, imply that small objects can be entirely allocated within the cache hierarchy without
   being backed by the main memory, which saves the bandwidth to fetch and evict the object.

3. Does the above reasoning mean that main memory can be thought of as a super large, direct-mapped last level cache?
   What kine of design changes this will bring to the memory architecture? (i.e. objects can be created in the L1
   and propagate down the hierarchy to the main memory, instead of always being backed by the main memory)

**Lowlight:**

1. The paper failed to mention that clzero instructions will prohibit main memory fetch if the line to be zero-initialized
   is not in the cache hierarchy. Otherwise, the LLC controller will fetch the line since a miss will be signaled, which 
   does not have any bandwidth benefit.

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
implicitly transferred to the main memory from the M state block without an explicit write back. Correctness is not 
affected, though, since the language runtime guarantees that freed objects will not be accessed, or undefined
behavior would occur if this happens. clundirty is implemented by sending a message to the LLC, and then the LLC using
a special downgrade message to revoke M states from all upper level caches as if an external downgrade were received.
The special downgrade differs from conventional downgrades such that it only changes M state lines to E, and leaves
E state lines unchanged. One optimization is that the downgrade can be performed on the way down the hierarchy from L1
to the LLC, since a M state line in the L1 indicates that all caches on the path from the L1 to the LLC must have already
acquired exclusive permission of the line, eliminating the need for the LLC to query its directory and sends downgrade
requests to upper levels caches that are not on the path.
This instruction is used when the cache line of a freed object is expected to be reused shortly before the line is
evicted from the cache hierarchy. In this case, not invalidating the line would be a merit, since otherwise we may
have to fetch the line from the memory on next access in the near future.

clclean instruction is somewhat in-between clinvalidate and clundirty. This instruction is implemented the same way as
clundirty, and in addition to changing the line state from M to E, it also moves the cache line to the bottom of the 
LRU stack on each level, indicating that the line is of low priority, and can be discarded immediately if the workload
imposes pressure on the cache. This instruction is used when the reuse distance of the freed object's memory is longer than
the one in clundirty, and shorter than the one in clinvalidate, which is more flexible than any of these two. The paper
also reports that clclean is the most effective instruction among the three in bandwidth and energy saving.

The next instruction type is clzeroX, which actually consists of three or more instructions, with X being 1, 2 and 3.
The clzeroX instruction zero-fills a cache line on the given address without reading the backing main memory, even if
the line does not exist in the cache hierarchy. The number X indicates the level of cache where the zero-initialized
line will be brought into. This instruction is implemented on the LLC as well. It is treated by the LLC coherence controller
as a write back operation from the upper level, which invalidates all shared or exclusive copies of the line in other 
caches and levels, if any of them exists. Then a cache slot with the address tag is allocated in the LLC, whose content
in the data array is filled with zero. No fetch request is sent to the DRAM to save bandwidth. The zero-initialized line
is also propogated to upper levels based on the value of X. The memory allocator uses this instruction to zero-initialize
objects before returning them to user application.
