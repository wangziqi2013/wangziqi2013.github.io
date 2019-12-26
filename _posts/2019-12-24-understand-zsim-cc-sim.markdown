---
layout: post
title:  "Understanding Cache System Simulation in zSim"
date:   2019-12-24 20:04:00 -0500
categories: article
ontop: true
---

### Introduction

zSim is a fast processor simulator used for modeling the bahavior of memory subsystems. zSim is based on PIN, a binary
instrumention tool that allows programmers to instrument instructions at run time and insert customized function calls.
The simulated application is executed on native hardware, with zSim imposing limited control only at certain points 
during the execution (e.g. special instructions, basic block boundaries, etc.). In this article, we will not provide 
detailed description on how zSim works on the instrumentation level. Instead, we isolate the implementation of zSim cache 
subsystems from the other parts of the simulator, and elaborate on how the simulated cache is architected and how timing 
is computed. For more information about zSim, please refer to the 
[original paper](http://people.csail.mit.edu/sanchez/papers/2013.zsim.isca.pdf) which gives a rather detailed description
of the simulator's big picture. And also, it is always best practice to read the official 
[source code](https://github.com/s5z/zsim) when things are unclear. In the following sections, we will use the official
source code github repo given above as the reference when source code is discussed. 

### Source Files

Below is a table of source code files under the /src/ directory of the project that we will be talking about. For each file
we also list its important classes and declarations for reader's convenience. One thing that worth noting is that a file is not
always named using the name of the class defined within that file. If you are unsure where a class is defined, simply doing
a `grep -r "class ClsName"` or `grep -r "struct ClsName"` will suffice for most of the time.

| File Name (only showing headers) | Important Modules/Declarations |
|:--------------------------------:|--------------------------------|
| memory\_hierarchy.h | Coherence messages and states declaration, BaseCache, MemObject, MemReq |
| cache\_arrays.h | Tag array organization and operations |
| cache.h | Actual implementation of the cache class, and cache operations |
| coherence\_ctrls.h | MESI coherence state machine and actions |
| repl\_policies.h | Cache replacement policy implementations |
| hash.h | Hash function defined to map block address to sets and to LLC partitions |
| init.h | Cache hierarchy and parameter initialization |
{:.mbtablestyle}

Note that zSim actually provides several implementations of caches, which can be selected by editing the configuration file. 
The most basic cache implementation is in cache.h, and it defines the basic timing and operation of a working cache, and 
no more. A more detailed implementation, called `TimingCache`, is also available, which adds a weave phase timing model 
to simulate cache tag contention (zSim simulates shared resource contention in a separate phase after running the simulated 
program for a short interval, assuming that path-altering interferences are rare). In this article, we focus on the functionality 
and architecture of the cache subsystem, rather than detailed timing model and discrete event simulation. To this end, we 
only discuss the basic cache model, and leave the discussion of timing cache to future works.

### Cache Interface

In this section we discuss cache subsystem interfaces. In zSim, all memory objects, including cache and memory, must inherit 
from the virtual base class, `MemObject`, which features only one neat interface, `access()`. The `access()` call takes 
one `MemReq` object as argument, which contains all arguments for the memory request. The return value of the base cache 
`access()` call is the finish time of the operation, assuming no contention (if contention is not simulated, then it is 
the actual completion time of the operation, as in our case). 

Cache objects also inherit from the base class, `BaseCache`, which itself inherits from `MemObject`, and defines another 
interface call, `invalidate()`. This function call does not take `MemReq` as argument, but instead, it takes the address 
of the line, the invalidation type, and a boolean flag pointer to indicate to the caller whether the invalidated line is 
dirty (and hence a write back to lower level cache is required). Note that in zSim, the `invalidate()` call only invalidiates
the block in the current cache object, and indicates to the caller via the boolean flag whether a write back is induced 
by the invalidation. It is therefore the caller's responsibility to write back the dirty block to the lower level using
a PUTX transaction, as we will see below. The return value of `invalidate()` is also the response time of the operation.

Overall, the cache object interface in zSim is rather simple: `access()` implements how the cache handles reads and 
writes from upper levels. `invalidate()` implements how the cache handles invalidations from the processor or lower levels
(depending on the position of the cache object in the hierarchy). Both methods are blocking: A begin time (absolute cycle 
number) is taken as part of the argument, and a finish time is returned as the cycle the operation completes.

### MemReq object

The `MemReq` object is used in two scenarios. First, an external component (e.g. the simulated processor) may issue a 
memory request to the hierarchy by creating a `MemReq` object before it calls the `access()` method (in zSim, we have an
extra level of `FilterCache`, in which case the `FilterCache` object issues the request). The caller of `access()` function
needs to pass the address to be accessed (`lineAddr` field) and the begin cycle (`cycle` field) of the cache access. The 
type of the access in terms of coherence is also specified by initializing the `type` field. In this scenario, no coherence 
state in involved, and the access type can only be `GETS` or `GETX`. In the second scenario, an upper level cache may
issue request to lower level caches to fulfill a request processed on the upper level. For example, when an upper level
cache evicts a dirty block to the lower level, it must initiate a cache write transaction by creating a `MemReq` object
and making it a `PUTX` request. In addition, when a request misses the upper level cache, a `MemReq` object must be
created to fetch the block from lower level caches or degrade coherence states in other caches. The process can be
conducted recursively until the request reaches a cache that holds this block or has full ownership, potentially reaching
beyond the LLC and reading from the DRAM. 

An interesting design decision in zSim is that when upper level cache issues a request to the lower level cache, the coherence 
state of the block in the upper level cache is determined by the lower level cache controller. This design decision is made 
to simplify the creation of "E" state, which requires information held by the lower level cache (i.e. the shared vector). 
As a result, when upper level caches issue the request, it must also pass a pointer to lower level caches such that the 
latter can assign the coherence state of the block when the request is handled. This pointer is stored in the `state` field 
of the `MemReq` object.

Another invariant is that `MemReq` object is only used for upper-to-lower requests, such as cache line write back, line 
fetch, or coherence invalidation. For lower-to-upper requests, such as block invalidation, we never use `MemReq` objects. 
Instead, lower level caches directly call into upper level cache's `invalidate` method, potentially broadcasting the
invalidation request to several upper levels recursively.

We summarize the fields and their descriptions in the following table.

| `MemReq` field name | Description |
|:--------------:|-----------|
| lineAddr | The cache line address to be requested |
| type | Coherence type of the request, can be one of the GETS, GETX, PUTS, PUTX |
| state | Pointer to the requestor's coherence state. Lower level caches should set this state to reflect the result of processing the request from the upper level |
| cycle | Time when the request is issued to the component |
| flags | Hints to lower level caches; Most of them are unimportant to the core functionality of the cache |
{:.mbtablestyle}

Note that this is not a complete list of all `MemReq` fields. Some fields are dedicated to concurrency control and race
detection, which will not be covered in this article. To make things simple, we always assume that only a single thread
will access the cache hierarchy, and hence all states are stable. In practice, multiple threads may access the same
cache object from different directions (upper-to-lower for line fetch, and lower-to-upper for invalidation). zSim has an
ad-hoc locking protocol to ensure that concurrent cache accesses can always be serialized.

### Cache System Architecture

In this section we discuss the abstract model of zSim's cache system. The cache system is organized as a tree structure,
with a single root representing the last-level cache (LLC), and intermediate nodes representing intermediate level caches
(e.g. L2). At the leaf level, we have the processor and the attached private L1d and L1i cache. Note that zSim does not 
"visualize" the cache hierarchy in the usual way, in which processors are at the top, and the LLC is placed at the bottom.
This may cause some naming problems since we used to call those that are closer to the leaf level "upper level caches", and those
that are close to the root level "lower level caches". To avoid such confusion, in the discussion that follows, we use 
the term "child cache" to refer to caches that are closer to the leaf level which usually have smaller capacity and operate
faster. We use the term "parent cache" to refer to caches that are closer to the root level which are larger but slower.

A cache object can be partitioned into multiple banks, each having different network latency from its child caches. 
Although this seems to break the tree abstraction of the cache hierarchy, the partitioned cache can still be regarded as
a logical cache object without losing generality. The partitioned parent cache models the so called Non-Uniform Cache Access 
(NUCA), which is typically applied to the LLC to increase parallelism and to avoid having a non-scalable monolithic storage. 
Accesses from child caches are first mapped to one of the banks using a hash function, and then dispatched to the parent 
partition (see `MESIBottomCC::getParentId`). In zSim, each partition is treated as a separate cache object, which can be 
accessed using the regular `access()` interface. Latencies from the children to the parent partitions are stored in a network 
latency configuration file, which is loaded at zSim initialization time. When a child cache accesses a partition of the 
parent, the corresponding child-to-parent latency value is added to the total access latency in order to model NUCA (see 
`parentRTTs` in `class MESIBottomCC`).

Although zSim supports both inclusive and non-inclusive caches (see `nonInclusiveHack` flag in MESI controllers), in
the following discussion, we assume that caches are always inclusive. The implication of inclusive caches is that 
when a block is invalidated or evicted in the parent level, all children caches that hold a copy of the same block must
also invalidate or write back (in case of a dirty line) the block to maintain inclusiveness. In addition, when a block
is loaded into a child cache by a request, the same block must also be loaded into all parent level caches as the 
requested is passed down recursively. The author of zSim also suggested in a code comment that the non-inclusive path is 
not fully tested, which may incur unexpected behavior. 

Three types of events can occur at a cache object. The first type is access, which is issued by the processor or by a 
child cache to fetch a line, write back a dirty line, or perform state degradation. Accesses are always issued to lower
level caches wrapped by the `MemReq` object. The second type is invalidation, which in the current implementation
is always sent from a parent cache to inform child caches that certain addresses can no longer be cached due to a
conflicting access or an eviction. Note that invalidations do not use `MemReq` objects, and instead they call the child
caches' `invalidate()` method with the type of the invalidation (`INV` means full invalidation; `INVX` means downgrade to 
shared state). The third type is eviction, which naturally happens when a new block is brought into the cache, but the 
current set is full. An existing block is evicted to make space for the new block, which also incurs invalidation
message sent to child caches if the evicted block is also cached by at least one child caches.

Each simulated cache object consists a tag array for storing address tags and eviction information, a replacement policy 
object that is purely logical, a coherence controller object which maintains the coherence states and shared vectors of 
each block, and access latencies for reading the tag array (`accLat`) and invalidating a block (`invLat`) respectively.
The following table lists all data members of `class Cache` and a short description. In the following sections we will
discuss these cache components individually.

| `Cache` field name | Description |
|:--------------:|-----------|
| cc | Coherence controller; Implements the state machine and shared vector for every cached block |
| array | Tag array; Stores the address tags of cached blocks |
| rp | Implements the replacement policy via an abstract interface |
| numLines | Total number of blocks (capacity) of the cache object |
| accLat | Latency for accessing tha tag array, ignoring contention |
| invLat | Latency for invalidating a block in the array, ignoring contention |
{:.mbtablestyle}

### Tag Array

The tag array object is defined in file cache\_array.h. Tag arrays are one-dimensional array of address tags that can be 
accessed using a single index. Although some cache organization may divide the array into associative sets, the 1-D array
abstraction is still used for identifying a cache block. All tag arrays must inherit from the base class, `CacheArray`,
which provides three methods: `lookup()`, `preinsert()`, and `postinsert()`. The lookup method returns the index of the 
block if its address is found in the tag array, or -1 if not found. Optionally, the lookup method will also change the 
replacement metadata of the cache line, which is indicated by the `updateReplacement` flag in the argument list. The `preinsert()`
method is called before inserting a new address tag into the tag array. This method will search the tag array for an empty
slot to store inserted tag. If an empty slot cannot be found, as should be the majority of the cases, an existing slot
will be made empty first by writing back the current block data, and then returning its index. The address to be written
back is returned to the caller via the last argument, `wbLineAddr`, and the index of the selected slot is the returned
value. `postinsert()` will actually store the new address tag into the target slot given both the address and the index
of the slot. 

Note that zSim only guarantees that `preinsert()` and `postinsert()` will not be nested, i.e. the pending insertion must 
complete before the next one could be performed. It is, however, possible that `lookup()` be called between the two methods 
as a result of write backs from child caches. One example is when a middle-level cache evicts a block that has been written
drity in child caches. After `preinsert()` returns, the cache controller processes the eviction of the block, which 
requires sending invalidations to child caches. On receiving the invalidation, the child cache holding a dirty copy of
the block will initiate a write back which directly sends the dirty block to the current cache, before the latter 
initiates a `PUTX` transaction to its parent cache. `lookup()` will be called to find the slot for writing back the dirty
block during the process of the `PUTX` request in the parent cache.

We next take a closer look at these three method functions. For simplicity, we assume set-associative tag storage, which is 
implemented by `class SetAssocArray`. On initialization, the number of blocks and sets are passed as construction argument.
The set size is computed by dividing the number of lines with the number of sets. The number of sets must be a power of 
two to simplify tag address mapping. The set mask is also computed to map any integer from the hash function to the range
from zero to set size minus one.

A hash function is associated with the tag array to compute the index of the set given a block address. The hash function
is relatively unimportant for set-associative caches, since we just perform an identity mapping (i.e. do not change the 
address) and let the set mask map the block address into the set number. For other types of tag arrays, such as Z array,
the hash function must be an non-trivial one, and can be assigned by specifying`array.hash` in the configurtation file.

The tag array is declared as a one-dimensional pointer named `array`. In order to access set X, the begin index
is computed as (`ways` * X), and the end index is (`ways` * (X + 1)). To perform an array lookup given a block address,
we first compute the set number by AND'ing the address with the set mask. Note that all block addresses have been right 
shifted to remove lower bit zeros. Then for each address tag in the set, we compare whether it equals the given address.
If true, a hit is indicated and the index of the tag array entry is returned. Otherwise we return -1.
If indicated by the caller, we also inform the replacement policy that the address has been accessed on a hit. The replacement 
policy object may then promote the hit block according to its own policy (e.g. moving to the end of the LRU stack).
