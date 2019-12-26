---
layout: post
title:  "Understanding Cache System Simulation in zSim"
date:   2019-12-24 20:04:00 -0500
categories: article
ontop: true
---

## Introduction

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

| `MemReq` Field Name | Description |
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

## Cache System Architecture

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

| `Cache` Field Name | Description |
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

A replacement policy object is responsible for deciding which block should be evicted, if any, when a new block is brought 
into the set. As discussed in the previous section, the replacement policy object stores its own metadata, which can be 
optionally updated on every tag array access.

The tag array is declared as a one-dimensional pointer named `array`. In order to access set X, the begin index
is computed as (`ways` * X), and the end index is (`ways` * (X + 1)). To perform an array lookup given a block address,
we first compute the set number by AND'ing the address with the set mask. Note that all block addresses have been right 
shifted to remove lower bit zeros. Then for each address tag in the set, we compare whether it equals the given address.
If true, a hit is indicated and the index of the tag array entry is returned. Otherwise we return -1.
If indicated by the caller, we also inform the replacement policy that the address has been accessed on a hit. The replacement 
policy object may then promote the hit block according to its own policy (e.g. moving to the end of the LRU stack).

In `preinsert()`, the tag array either finds an empty slot, or more likely, finds a slot to be evicted. This is exactly 
where the replacement policy comes into play. The `preinsert()` method first initializes a `SetAssocCands` object, which
is just a pair of indices indicating the begin and end index of the set in which replacement happens, and then passes
this object to the replacement policy's `rankCands()` method. The `rankCands()` method returns the index of the selected
block, which is then returned together with the address tag. Note that `preinsert()` has no idea whether a block is 
invalid or dirty when it makes decision on eviction. The coherence controller, on the other hand, knows the exact state 
of the selected block, and will enforce correct behavior. As a result, the replacement policy will query the state of the 
block when it evaluates the block for eviction to avoid evicting invalid blocks.

The logic of `postinsert()` is simple. The replacement policy is notified that the selected block has been invalidated,
and that a new block is inserted. The metadata for the block will be updated to reflect the replacement. The new address
is also written into the array.

### Replacement Policy

The replacement policy is implemented as a ranking function. The policy can be specified using the `repl.type` key in the 
configuration file. In this section we only discuss LRU, which is implemented by `class LRUReplPolicy`. zSim implements 
LRU using timestamps. A single global timestamp is incremented for every access to the tag array. Each block also has a 
local timestamp which stores the value of the global timestamp when it is accessed. A larger local timestamp means the 
block is closer to the MRU position. 

The ranking function, `rankCands()` (also `rank()`), iterates over the `SetAssocCands` object, and for each block in the set, 
it computes a score based on the LRU counter. If the LRU policy is sharer-aware, the score will be affected by: (1) the 
validity of the block; (2) the number of sharers; and (3) the local timestamp value. The higher the score is, the less
favorable it is to evict the block. The replacement policy selects the block with the smallest score as the candidate
for LRU eviction.

## Simulating Cache Coherence

### Coherence Overview

zSim simulates MESI coherence protocol using an implementation of directory-based MESI state machine across the memory hierarchy.
zSim does not model the full set features of the protocol, since only stable states are simulated. zSim also does not model the 
on-chip network traffic incurred by coherence activities. Latencies of the network is assigned statically, and they will 
not change based on network utilization. 

Each cache object has a coherence controller, which maintains the coherence states of all blocks currently residing in the 
cache. Since zSim caches are inclusive, the coherence directory is implemented as in-cache sharer lists, one for each cached 
block. The number of bits in the sharer list per block equals the number of children caches. A "1" bit in the list indicates 
that the corresponding child cache may have a cached copy on the same address, dirty or clean. The sharer list is queried when invalidations are sent to the children caches, and is updated when a new block is fetched by a child cache.

The coherence controller is further divided into two logical parts: A "top controller" maintains the directory and sends 
invalidation to children caches, and a "bottom controller" maintains the state for cached blocks and handles requests from
child caches. These two logical parts are largely independent from each other, and are implemented as separate modules.
The following table lists the coherence controller module name and the responsibility of the module.

| Coherence Module Name | Description |
|:--------------:|-----------|
| CC | Virtual base class of the controller; Specifies interface of coherence controllers |
| MESIBottomCC | Bottom coherence controller; Maintains block states and handles child requests | 
| MESITopCC | Top coherence controller; Maintains directory states and handles invalidations |
| MESICC | Includes both MESIBottomCC and MESITopCC to implement the coherence controller for non-leaf level caches |
| MESITerminalCC | Coherence controller for leaf level caches (e.g. L1d, L1i). Only includes MESIBottomCC, since leaf level caches do not have directory states to maintain |
{:.mbtablestyle}

We also list the members of `class MESIBottomCC` and `class MESITopCC` to aid our discussion of coherence actions in the 
following sections.

| `MESIBottomCC` Field Name | Description |
|:--------------:|-----------|
| array | The coherence states of cached blocks; States are one of the `M`, `E`, `S`, `I` as in the standard MESI protocol |
| parents | A list of parent cache partitions. A hash function maps the block address into parent ID when the parent cache is to be accessed. All parent cache partitions collectively maintains state for the entire address space |
| parentRTTs | A list of network latencies to parent partitions; This models NUCA |
| numLines | Number of blocks in the cache. Also number of coherence states |
{:.mbtablestyle}

<br />

| `MESITopCC` Field Name | Description |
|:--------------:|-----------|
| array | The sharer vector of cached blocks. Each entry in the array is a bit vector in which one bit is reserved for each child cache. A boolean flag also indicates whether the block is cached by children caches in exclusive states (used for silent upgrade). |
| children | A list of children cache objects. Children caches are assumed to be not partitioned, and each child cache maintains state of its own |
| childrenRTTs | A list of network latencies to children caches; This can model L1i and L1d |
| numLines | Number of blocks in the cache. Also number of directory entries |
{:.mbtablestyle}

One unfortunate fact with zSim source code is that methods of `class MESICC` and `class MESITerminalCC` have the same name 
as methods of `class MESIBottomCC` and `class MESITopCC`, which adds significant difficulties navigating the source files. 
The rule of thumb is that `class MESICC` and `class MESITerminalCC` methods are all defined in coherence\_ctrls.h, while 
most of the `class MESIBottomCC` and `class MESITopCC` methods are defined in the cpp file.

We next describe coherence actions one by one.

### Invalidation

Invalidation can be initiated at any level of the cache by calling the `invalidate()` method. In fact, even the coherence 
protocol calls this method to invalidate blocks in child caches. The semantics of `invalidate()` method guarantees that
the block to be invalidated will not be cached on the level it is called as well as all children levels. In this section
we show how `invalidate()` interacts with cache coherence.

The `invalidate()` method first performs a cache lookup using the `lookup()` method of the tag array (not updating LRU states).
If the block is found in the tag array, the address and the index of the block is passed to the coherence controller's 
method `processInv`. Note that `invalidate()` handles both downgrades (`INVX`) and true invalidations (`INV`). The type
of invalidation is specified using the `type` parameter. When downgrade is requested, the current level 
on which `invalidate()` is called and levels below are assumed to hold a block in `M` or `E` state.

In a non-terminal coherence controller, `processInv()` simply calls `processInval()` on `tcc` and then calls the method 
of the same name on `bcc`. The completion cycle, however, is the cycle when `tcc` finishes broadcasting. This reflects an
important assumption made by zSim: broadcasting is on the critical path, while transfer of dirty data and local state
changes are not.

In `tcc`'s `processInval()`, `sendInvalidates()` is called to broadcast the invalidation request to child caches that 
have a "1" bit in the sharer list. To elaborate: This function walks the sharer list of the block, and for each potential
sharer, it calls the cache object's `invalidate()` method recursively (recall that we are now in the initial `invalidate()`'s
call chain). The type of invalidation and the boolean flag indicating dirty write back are passed unmodified. zSim assumes
that all invalidations are signaled to child caches at the same time. The completion cycle of a single invalidation is 
computed as the response cycle from the child cache plus the network latency. Since all requests are signaled in parallel,
the final completion cycle is the maximum of all child cache invalidations. After all children caches have responded,
the controller changes the directory entry of the current block based on the invalidation type. For full invalidation,
the directory entry is cleared, since the block no longer exists in the cache. For downgrades, the directory entry's 
exclusive flag is cleared, but we keep sharer list bit vector intact.

After `tcc`'s `processInval()` method returns, `bcc`'s `processInval()` method is invoked to handle local state changes.
For full invalidations, we always set the coherence state to `I`, and set write back flag if the state is currently `M`
to signal a dirty write back to the caller. Note that since at most one cache in the entire hierarchy can have a dirty 
copy, the dirty write back flag will be set exactly once during the invalidation process. For downgrades, we simply change
the current `M` or `E` states (other states are illegal) to `S`, and set the write back flag if the current state is `M`.
No actual write back takes place during invalidation. The caller of cache object's `invalidate()` method should handle dirty
write back by starting a `PUTX` transaction on parent caches or to other memory objects (e.g. DRAM, NVM).

### Eviction

Cache line eviction is triggered naturally as new blocks are loaded into the cache when the set is full. No external 
interface is available for the cache object to initiate an eviction. Instead, the cache controller calls `processEviction()`
on the coherence controller when the tag array's `preinsert()` returns a valid block number, indicating that a block
should be evicted. Coherence controller's `processEviction()` calls the method of the same name (unfortunate coincidence) 
on `tcc` and `bcc` respectively, in this order, and returns the `bcc` completion time as the eviction completion time.
Note that by returning `bcc`'s completion time, zSim assumes that `tcc`'s broadcasting and `bcc`'s write back are serialized, 
such that the latter can only proceed after the former returns. This design decision is reasonable, as dirty write back 
needs to see the dirty line first, which is transferred in a side channel from one of the child caches to the coherence
controller. 

The `processEviction()` method of `tcc` simply wraps `sendInvalidates()` method, which signals children caches of the 
cache line invalidation operation. The invalidation type is set to `INV`, indicating that blocks must be fully invalidated.
The dirty write back flag is passed to a local variable of coherence controller's `processEviction()`, which is then passed 
to `bcc`'s `processEviction()` to actually perform the write back. 

After sending the invalidation, `bcc`'s `processEviction()` method changes the local state and conducts the write back.
It first checks the dirty write back flag which is set by `tcc`'s invalidation process. If the flag is set, meaning a
child cache has a dirty block on the invalidated address, the `bcc` first changes the local state from `E` or `M` to `M`
(other from states are illegal). Note that local `E` state implies that the child cache first reads the line using GETS,
acquiring the line in `E` state, and then does a silent transition from `E` to `M`. Local `M` state implies that the 
child cache originally acquired the line using `GETX`, which sets all caches holding the block to `M` state along the way
the block is passed to it. Also note that zSim assumes that children caches will pass the dirty block to the current controller
using a side channel, which is not on the critical path of broadcasting, instead of using regular `MemReq`. This assumption 
is justified by the fact that writing data back level-by-level is unnecessary, since these written back copies between 
the bottommost dirty block owner and the current cache object will be invalidated anyway.

The type of the write back depends on the state of the block after handling dirty write backs from children caches.
If the block state is `E` or `S`, meaning no dirty data needs to be written, the coherence controller creates a 
`PUTS` `MemReq` object, and calls parent cache `access()` method to handle the write back synchronously. If, on the 
other hand, the block state is `M`, a `PUTX` `MemReq` object is created and fed to the parent cache's `access()` method. 
`I` state blocks will be simply ignored, since they neither have any sharer nor require any form of write back.
In all cases, the completion cycle of the parent `access()` method will be returned to the caller as the completion
cycle of the eviction operation. As discussed in early sections, the current block state will be set by the parent
cache when the request is handled by `access()` method. After parent cache `access()` returns, the block state 
should be `I`, indicating the block is no longer cached in any part of the hierarchy down below the current level.

One design decision is whether to send `PUTS` requests to parent caches when the block is clean. In general, sending clean 
write backs help parent cache to manage their sharer lists by removing the sharer eagerly and making the list precise.
Imprecise sharer lists do not affect correctness, but will incur extra coherence messages to caches that do not actually
hold the block. zSim decouples the creation and processing of `PUTS` requests. `PUTS` requests are always sent whenever possible,
but parent caches just ignore them. Since zSim does not model network utilization, and assumes that all invalidations
are sent in parallel, not cleaning the sharer list eagerly will not affect simulation result. 

### GETS/GETX Access

We discuss `access()` method in two sections. In this section, we present how `GETS` and `GETX` are handled. In the next
section, we present `PUTS` and `PUTX`.

The cache object's `access()` method begins by performing a lookup in the tag array. If the address is not cached,
and the request is a `GETS` or `GETX`, then we need to first evict an existing block (`preinsert()` and `processEviction`), 
and then load the intended block from parent level caches by calling coherence controller's `processAccess()`. If the parent 
level cache does not contain the block, this process may be recursively repeated until reaching a parent level cache that 
holds the block with sufficient permission, or finally hit the DRAM (or other types of main memory). If the address is 
cached, we still need to call `processAccess()` to update its coherence state, since a cache hit may also change the 
coherence state of the block (e.g. if a `GETX` request hits a `E` state line, the state will transfer to `M` silently).
The invariant is that no matter a block is evicted or hit, `processAccess()` always sees a valid cache line number, 
which is the slot for loading the new block or changing existing coherence states (recall that after a block is evicted,
its coherence state in the former holder will be `I`).

In the terminal level coherence controller, `processAccess()` only calls `bcc`'s method of the same name. For `GETS` requests,
we check the current coherence state. If it is `E`, `S` or `M`, then the controller already has sufficient permission for
accessing the block, and no coherence action will take place. If the block is in `I` state, the block needs to be brought
into the cache from a parent level cache. To this end, the controller creates a `GETS` `MemReq` object, and calls parent 
cache `access()` method recursively. The coherence state of the current block will be set by the parent level `access()` 
method after it returns, which should be either `S` (already peer caches holding the block) or `E` (when it is the only 
holder of the block in parent's sharer list, and the parent itself also has `E` or `M` permission). 

For a `GETX` request, if the current block state is `E`, then the block silently transfers to `M` state without notifying
the parent cache. The fact that a dirty block is held by the current cache will be available to the parent when an invalidation
forces the `M` state block to be written back. If, however, the current state is `I` or `S`, then just like the case for
`GETS`, the controller creates a `GETX` `MemReq` object, and feeds it to parent cache's `access()` method in order to
invalidate all shared copies held by its peer caches (and peers of its parent, etc.). The final state of the block will 
be set by the parent instance of `access()`, which should be `M`.

The handling of `GETS` and `GETX` are more complicated on non-terminal caches. There are two invariants in non-terminal 
coherence controllers. The first invariant is that a controller can grant permission to its children caches only if
it holds the same or higher permission. For example, a controller holding an `S` state line should not grant `M` permission
to the child without acquiring `M` permission with its parent first. The second invariant is that non-terminal cache 
controllers always send data it has fetched to children caches (except for prefetching, which we do not discuss). 

On receiving a request from a child cache, a non-terminal coherence controller first attempts to acquire equal or higher
permission requested by the child cache if it does not hold the block in that permission. This translates to calling 
`bcc`'s `processAccess()`, which has exactly the same effect as in a terminal controller. After `processAccess()` returns, 
the current cache should have sufficient permission to grant the child cache's request, which is performed by calling
`tcc`'s `processAccess()`. This function takes a boolean flag indicating whether the current state of the block is exclusive
(i.e. `M` or `E`) as one of the arguments (recall that `tcc` has no access to the current state of the block, but only the 
state of the child block). The function also takes argument on whether a dirty write back is incurred as a result
of permission downgrade in one of its children caches. 

At a high level, `processAccess()` will set the child block state and its own directory state based on the type of the 
request and the state of the block in the current cache. We elaborate the concrete handling case-by-case. If the request 
is `GETX`, then we check the sharer list to see whether the block is currently shared by multiple children caches. 
If true, `sendInvalidates()` is called to revoke all shared cache lines in children caches. Note that when `tcc` begins
processing the request, the current cache block state must already be exclusive. This does not contradict the fact
that one or more of its children caches may have a shared or exclusive copy of the block. If the invalidation results 
in a dirty write back, the flag will be set, and the write back will be processed by the coherence controller. After
invalidation, we set the requestor as the exclusive owner of the cache line by clearing all bits in the sharer list except
the request's. 

If the request is `GETS`, the current state of the block after `bcc`'s `processAccess()` can be any of the valid state. 
In MESI protocol, if the current cache holds the block in an exclusive state, and there is no other sharer of the block, 
`tcc` could grant `E` permission to the requestor, since it is certain that the current cache holds a globally unique copy 
of the line, and could grant write permission to one of its children. If, on the other hand, that the current state is exclusive,
but a different child cache owns the block in exclusive state, then invalidation is still needed to downgrade the current
owner of the line to shared state (using `INVX`), before `S` permission could be granted to the requestor. If the current
state is shared, meaning that the block is not exclusively owned by the current cache, but also shared by other caches,
the requestor simply gets `S` state without invalidation. In all three cases, the requestor is marked in the sharer list. 