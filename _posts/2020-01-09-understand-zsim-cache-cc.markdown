---
layout: post
title:  "Understanding Cache Coherence Concurrency Control Protocol in zSim"
date:   2020-01-09 17:12:00 -0500
categories: article
ontop: true
---

## Introduction

In a previuos article, we discussed cache coherence protocol implementation and simulation in zSim. We assumed a no-race
condition context in which the current thread has full permission to access the entire cache hierarchy, and no intervening
operations from other theads will alter the cache state. While this assumption simplifies discussion, it is unrealistic 
in practice, since zSim is designed to simulate multiple threads concurrently. To deal with concurrency, we must synchronize
threads properly to achieve the following two goals. First, the state of a `MemObject`, such as the tag array and coherence
state array, must be consistent while a thread accesses them. Partial states must not be observed. Second, operations on
the cache object must serialize property, forming a global partial ordering. If one thread observes or overwrites the 
state written by another thread, serializing after it, then the latter must not serialize before the former by observing 
or overwriting states written by the former. This way, cache operations can form a global partial ordering, which allows 
a total ordering to be determined. Logically speaking, in a total ordering, the concurrent execution of cache operations 
is equivalent to a serialized execution in terms of input, output of each operation as well as the final state. The
order of serialized execution is given by the total ordering.

In the following discussion, we present thread synchronization within zSim's cache hierarchy implementation in detail. 
Note that concurrency control here does not refer to concurrency enabled coherence protocol with transient states. zSim 
only models the basic MESI protocol in which all states are stable. Transient state simulation requires a complicated 
state machine, which cannot be easily implemented and verified. zSim applies concurrency control protocol only to protect 
its internal data structure and to ensure correct semantics of coherence actions. 

### Source Files and Documentation

We list source files and modules related to our discussion in the following table.

| File Name                        | Important Modules/Declarations |
|:--------------------------------:|--------------------------------|
| cache.h/cpp | `class Cache`'s `access()` and `invalidate()` shows how synchronization routines are called during a cache operation. |
| coherence\_ctrl.h/cpp | `class MESITopCC` and `class MESIBottomCC` implement request lock and invalidation lock respectively. |
| filter\_cache.h/cpp | `class FilterCache` implements a low overhead traffic filter above L1 cache to avoid the locking protocol. |
| init.cpp | Initialization of filter caches |
| locks.h | Futex lock object type declaration. |
{:.mbtablestyle}

Besides, our discussion is based on a tutorial on zSim memory simulation published by zSim developers at MIT. The tutorial
is focused on teaching the audience on how to extend zSim with user customized modules, while this article is more focused 
on explaining how things work in zSim's existing code base. The tutorial can be found 
[here](http://zsim.csail.mit.edu/tutorial/slides/memory.pdf).

## Concurrency Control in Cache Objects

### Two-Phase Locking (2PL)

Generally speaking, two-phase locking is the most commonly used lock-based concurrency control protocol. It is based on
the lock and unlock primitive, which acquires and releases exclusive access of a thread to a single object. zSim's cache 
concurrency control protocol is also a variant of 2PL. We briefly describe 2PL in this section. 

2PL requires objects to be locked before they are accessed. The read and write set may not be known in advance, which can 
be derived dynamically as the critical section is executed. The most important aspect of 2PL is the two-phased property:
Objects are locked as they are accessed within a critical section. No object should be released before the last object
is locked. This property essentially divides the execution of the critial section into two phases: a growing phase in which
locks can only be acquired, and a shrinking phase in which locks can only be released. 2PL property guarantees serializability.
One easy way to visualize this is to consider what if one thread A blocks another thread B by holding a lock B intends to
acquire. In this case, B must serialize after A, and not vice versa, since B can only read or overwrite state written by A,
but A must not access state written by B. We prove this by contradiction. The first half is easy, since B blocks on an
object A will read or write. After A releases the lock, B could read or write the object as well, serializing itself
after A. The second half can be proven by contradiction. Assume that A also accesses B's state. This implies that thread
A must have acquired a lock B releases. According to the 2PL property, B must not release any lock before it acquires 
all locks for objects in its working set. We can infer that B must have already been in the shrinking phase. This, however,
is inconsistent with the fact that B blocks on A, since this implies that B is still in growing phase, and has at least
one or more locks to acquire. A contradiction! Note that this is not the complete correctness proof of 2PL, since pair-wise
cycle-freedom is not sufficient to guarantee cycle-free of the final dependency cycle, if cycles with more than two nodes 
exist. The full correctness proof of 2PL uses induction on the number of nodes in the cycle, and is rather straightforward,
which we do not present.

### 2PL in Cache Invalidate

Let's consider cache line invalidation first. When an invalidation is triggered either by an eviction or by an external
event, the `invalidate()` method of the `class Cache` object is invoked. At the beginning of this method, we call
`cc->startInv()`. This function does nothing else besides calling `bcc->lock()`. If we further look into class `MESIBottomCC`,
we will find that this function is nothing more than just calling `futex_lock()` on its member veriable `ccLock`. This
variable is declared as `lock_t`, which in file locks.h is declared as `volatile uint32_t` type. In one word, the `bcc`
object implements a simple lock as a 32 bit volatile integer. The lock is acquired using library call `futex_lock()`
and released using `futex_unlock()`. 

In this article, we do not cover the details of these two functions. To be short: The custom futex lock in zSim combines 
spin lock with kernel futex lock. When the wait period is small, this function will not trap into the kernel, and instead 
only spins on the volatile variable. When the waiting time exceeds a certain threshold (1000 spin loops), it is expected
that the wait would be long, and the thread traps into the kernel by calling `futex()` system call via GNU portal `syscall()`
in order to block the thread in the kernel, which allows better usage of CPU cycles at the cost of an expensive system 
call.

For some unknown reason, the author of zSim does not add `endInv()` into `class MESICC` and `class MESITerminalCC` to 
release the lock in `bcc` object. Instead, the lock is released at the end of `processInv()` in both classes, which
is the last action taken before `processInv()` and cache object's `invalidate()` returns. Recall that `validate()`
is called recursively in function `sendInvalidates()`, which is used by `processInval()` in `class MESITopCC`. This 
is essentially a slightly modified 2PL protocol, in which locks in each cache object's `bcc` are acquired while the 
invalidation message propagates down the hierarchy to child caches, and released when the `invalidation()` on the current
level returns. In this model, there seems to be multiple growing and shrinking phases if a cache block is shared by
multiple children caches, since we invoke `invalidate()` once for a child cache that holds the block, which releases
the lock before we invoke the same function for the next child cache. This protocol, however, still guarantees the 
atomicity of invalidation operatons in the presence of concurrent invalidations at any level, due to the special
structure of the cache hierarchy and the way invalidation request propagates. We next present the correctness proof. 

As shown in the 2PL correctness proof, the risk of releasing locks early resides in the fact that another thread B may 
serialize after the current thread A by accessing the object whose lock is released, and in the meantime serialize
before thread A by having A accessing its state after A releases the lock, hence introducing a dependency cycle. We 
argue that these two will never happen together in the cache hierarchy based on two reasons. First, invalidations
can only propagate from top to bottom, but not vice versa. Second, the cache hierarchy is organized as a tree,
with the root being the LLC and leaves being L1 private caches. If the root of a subtree is locked, no request
can be propagated to the subtree before the subtree root is released.

We prove the correctness of the protocol by a case-by-case discussion. Without losing generality, we assume that thread 
A begins invalidation on node X of the hierarchy. In the first case, thread B starts an invalidation on a node Y 
within the subtree. Assuming thread B's working set (cache objects it touches) overlaps with thread A's working set (otherwise 
the proof is trivially done). Then thread B may access cache object Y before thread A accesses them or after. In the first 
subcase, thread B will lock node Y until its invalidation completes. In this subcase, thread A cannot access any node
in B's working set before it completes, since thread A will otherwise block on cache Y, and that B's working set will
only contain nodes under Y. Thread A therefore serializes before thread B. In the second subcase, B accesses Y after A 
does. Since A releases the lock on Y only after it has done with all children caches of Y, B can only lock Y and start
its invalidation process after A completes invalidation on substree starting from Y. Given that a cache object is never
accessed twice, this implies that B can only access cache objects after A does, and A will never access states written
by B, serializing A before B.

In the second case, B starts invalidation on a node Y outside of the subtree. We similarly assume that their working 
sets overlap. The proof is identical to the previous one, except that we switch A, B and X, Y.

Combining the two cases, we conclude that no matter how invalidations are interleaved, we can always establish a partial
ordering between any pair of them. Furthermore, the partial ordering only exists when two invalidation threads A and B
share at least one cache object in their working sets. This suggests that w.l.o.g. one of A, B must start invalidation
in the subtree of another. Recall from the 2PL proof that we still need to prove the "no cycle" property for arbitrary
number of threads. We next present the proof.

The proof uses structural induction on the tree hierarchy, with notation (X, Y) meaning "the root of subtree Y is locked 
by an invalidation starting at node X". Using this notation, the above conclusion can be expressed as: If A is serialized
before B, then either A is above B, and (A, B) -> (B, B), or A is below B, and (A, A) -> (B, A). Here "->" means "happens 
before". Furthermore, according to transitivity of the "happens-before" relation, if we know (A, B) -> (C, D) and 
(C, D) -> (E, F) then we have (A, B) -> (E, F).

The induction hypothesis says if the invalidation protocol running on a subtree of height D will not incur cycles, then for 
trees with depth (D + 1), there will be no cycle either. In the base case, D equals 1, and we only have one single cache.
in which case the hypothesis trivially holds. Assuming that the property holds for all all trees with height less than or
equal to D. We next prove by contradiction that the property still holds for tree of height (D + 1).

Without losing generality, we assume that a cycle is formed after the invalidation protocol is executed on the current
root node X (the node that has height D + 1). The cycle is in this form: `X -> ... -> Y -> ... -> Z -> ... -> X`, in which
Y and Z are nodes in the original subtree of depth D, and notation like X -> Y indicates that the invalidation protocol
starting at X is serialized before the protocol starting at Y. Since both Y and Z are below X in the tree, according to 
what we have proved above, we know (1) (X, Y) -> (Y, Y) and (2) (Z, Z) -> (X, Z). Since Y -> Z, but it is unclear if Y
is above Z or below Z, we need a case-by-case discussion. Assuming Y is below Z, then we have (3) (X, Z) -> (X, Y)
since the protocol starting X always lock cache objects on the path down the hierarchy. We also know (4) (Y, Y) -> (Z, Y)
since Y -> Z. Put them all together in the order (2)(3)(1)(4), we have the following relation: 
`(Z, Z) -> (X, Z) -> (X, Y) -> (Y, Y) -> (Z, Y)`. Since ``(Z, Z) -> (X, Z) -> (X, Y)` implies that Z has released the 
lock on its root, otherwise X will not be able to lock Y. This contradicts with (Z, Y), indicating that invalidation
starting at Z has not terminated yet, since it locks node Y after X locks node Z. A contradiction!

In the second case, we have Y above Z. Relation (1) and (2) do not change. Relation (3) becomes (Y, Y) -> (Y, Z) since
the protocol starting at Y always locks the node itself first. (4) becomes (Y, Z) -> (Z, Z). If we put them together in 
the order (1)(3)(4)(2), we have `(X, Y) -> (Y, Y) -> (Y, Z) -> (Z, Z) -> (X, Z)`. Similarly, `(X, Y) -> (Y, Y)` suggests that
X has released lock on Y, but `(Z, Z) -> (X, Z)` indicates that X acquires lock on Z after it released lock on Y.
This is contradictory to the protocol, hence concluding the proof.

### 2PL in Cache Access

In the cache object's `access()` method, we call `cc->startAccess()` at the beginning, and conclude the access by calling 
`cc->endAccess(req)` at the end of the function. If we look into what these two functions do, we will find that they are 
essentially the same as invalidation if we ignore the operations on `bcc`'s lock and `req.childLock` for now. `startAccess()`
simply acquires the same lock on `tcc` object, and `endAccess()` releases the `tcc` lock.

The 2PL pattern is again found in the cache access protocol, this time using the lock word in `tcc` object. Different from
cache invalidation, the cache access locking protocol is standard 2PL, based on two observations. First, cache object's 
`access()` is called recursively if the current level does not contain the block or does not have sufficient permission.
This clearly divides the execution of the topmost `access()` into two phases. In the first recursion phase, we keep calling
into parent cache's `access()` method, and acquiring locks. No lock will be released in this phase, which corresponds to 
the growing phase in 2PL. In the second phase, we decurse from the parent level function, and before function returns,
the lock is released. This corresponds to the shrinking phase in 2PL. Based on the above reasoning, we can claim that
the cache access protocol is serializable.

## Synchronizing Cache Access and Invalidation

### What Does Not Work

Let's forget about lock words in `bcc` and `tcc` temporarily, and consider how a locking protocol can be implemented
to synchronize between cache access and invalidation.
One big challenge of synchronizing cache invalidation and cache access is to design a protocol that both scale to large
cache hierarchies and do not introduce deadlock. On one extreme of the spectrum, we just use a big global lock for all
accesses to the cache hierarchy. This obviously guarantees correctness, at the cost of performance and scalability. On the
other end of the spectrum, we use fine-grained lock-coupling, releasing the lock on the previous node after acquiring 
lock on the current node. This scheme, unfortunately, needs to take care of various transient states, since a pending
request may be later overridden by another request on the same slot, forcing us to use transient states to track these
cascaded request on the same block. One example is a pending block that is supposed to be fetched in M state 
being requested by a `GETS` before the fetch completes. The request will not be blocked since the cache object is not
locked. In this case, we must remember the transition from M to S using a transient state while the block is being fetched.
This is similar to what actually happens in a high performance coherence protocol implemented on hardware, but is 
definitely over-complicated for a simulator like zSim.

One compromise is to let invalidation and access use the same lock, and each procedure continues to use 2PL for ensuring
serializability. Unfortunately, this protocol suffers from deadlock, since there is no globally agreed order on the acquisition
of locks. One example is given in the slides (see above sections for the link) where two threads, A and B, start concurrent 
requests on cache objects X and Y respectively. Assuming these two have a common parent cache Z. A requests a block in
S state, shared by both X and Y, to be upgraded to M state, while B requests a block that is currently not in cache Y.
At the beginning, A locks X and B locks Y. Then A proceeds to cache Z, locks it, and starts an invalidation transaction 
to invalidate the copy in cache Y. The invalidation transaction attempts to lock Z, but is blocked on the lock currently
held by thread B, since we assume that both types of transaction will use the same lock. Thread B then attempts to lock 
cache Z. This, unfortunately, introduces a deadlock, since now B is waiting for A to unlock cache Z, while A is waiting
for B to unlock cache Y. 

Sorting the lock set on addresses before the critical section is also infeasible, since both protocols derive
their lock set (lock words in the working set cache objects) dynamically, which means that the lock set cannot
be known in advance.

### Invalidation-Freedom of Subtrees

One simple lemma is that no matter what the resulting protocol will be like, both `tcc` and `bcc` locks must be acquired
when the thread access the tag, coherence, and sharers array of a cache object, since the thread must have exclusive access 
to the object to avoid corrupting the state. A second lemma is that on the tree hierarchy, if we acquire the 
invalidation lock on a subtree rooted at X, then no invalidation may propagate from any level above X down to any node
within the subtree X, since invalidation requests need to acquire the invalidation lock on X first before they can propagate.
At anytime, as long as we have acquired the invalidation lock on node X, we can conclude that no invalidation can be 
propagated from any level above X. This lemma, however, is still not strong enough to guarantee no invalidation can ever 
happen in the subtree X, since invalidations can be triggered within tree X by requests initiated at leaf level. We therefore 
need the third lemma, which says that if nodes on the path from node X to a particular leaf node Y are all access locked, 
and that the invalidation lock on node X is also acquired, then no invalidation may happen within the path from X to Y. 
This is because in zSim, invalidations can only be triggered by three events: eviction, `GETS` downgrade, and `GETX` invalidation. 
In order for the invalidation to propagate to anynode in the path from X to Y, these three events must be able to reach 
a node in the path. This is, however, impossible, since the access locks are all acquired, and any attempt to access nodes 
on the path will be blocked until the access locks are released. In addition, no invalidation may propagate from higher 
levels than X into the subtree, as we have shown in the second lemma.

Note that in the above reasoning, we assumed that invalidations can only be triggered by cache accesses. One implication
is that zSim does not expect programmers to call `invalidate()` manually on any intermediate cache object except the last 
level cache, since this will break the invalidation-free property we just proved above. For last level caches this will 
be fine, since the invalidation lock on node X is always sufficient to ensure the no-invalidation property.

Based on the above three lemmas, we can now take a look at `startAccess()` and `endAccess()` in `class MESICC` to understand
the locking protocol. Recall that `startAccess()` is called at the beginning of each `access()` method of a cache object,
and `endAccess()` is called after everything has completed on the current level. The cache access locking protocol
maintains the invariant that at any moment in time when the thread is working on cache X to serve a request initiated from
leaf cache Y, as long as we are between `startAccess()` and `endAccess()` of X, it is guaranteed that the access locks on 
the path from X to Y, as well as the invalidation lock of X, are acquired. Under this invariant, we can safely assume that
no concurrent invalidation and access will alter the state of any node on the path from X to Y, and all member functions
of the coherence controller class can be written in a race-free manner. In order to implement this invariant, in addition
to the 2PL-style acquisition and release of `tcc`'s lock, when the thread moves from the current cache Z to its parent W,
we first release the invalidation lock on cache Z, allowing pending invalidations to proceed to Z and its children caches,
and then attempt to acquire the invalidation lock of W. This will create a short window in which invalidations can be 
propagated from W to Z, and the acquisition of W's invalidation lock will only be granted after the current active invalidation 
(if any) completes on cache W, hence breaking the invariant. After the invalidation lock of W are acquired, the invariant
is re-established, and we can access cache W's internal state safely. In `endAccess()`, we maintain the invariant by first
acquiring the invalidation lock on the child node Z on the path, and then releasing the invalidation lock on parent W.
Note that here we do not create any short window of vulnerability which allows invalidations to be propagated to the subtree
rooted at W, because we lock the child before unlocking the parent.

The locking protocol described above will not introduce any deadlock, since when cache accesses propagate up in the 
hierarchy from Z to W, they will not be blocked by invalidation on cache W, since we release the invalidation lock
on Z before acquiring the invalidation lock on W. This allows the invalidation to propagate from W to nodes in the 
subtree. The cache access will only be granted the invalidation lock on W after the current active invalidation completes
and releases the invalidation lock on W, serializing the access after the invalidation. 

By allowing invalidation requests to propagate during the short window between releasing lock on Z and acquiring lock
on W, we solved the deadlock problem. This, however, incurs a new problem: After we acquired the invalidation lock on W, 
internal states of cache objects below the subtree rooted at W may have been altered by the invalidation. For those cache 
lines affected by the invalidation, we only care those that are relevent to the current request, i.e. that have the same 
tag as the requested address. Also, given the fact that the cache hierarchy is inclusive, we can just check cache Z for 
the state change of the slot that will be affected by the request. We next describe this process in details.

### Protocol Description

In `startAccess()`, we first release the lock word pointed to by `req.childLock`. If we take a look at `processAccess()`
of class `MESTBottomCC`, it is not difficult to figure out that the `childLock` field of `class MemReq` is simply
a pointer to the invalidation lock of the child node when the access request is handled by its parent. Then we lock
both `bcc` and `tcc` using their `lock()` method. After both are locked, according to the discussion above,
we do not need to worry about state changes on the path anymore, but we should handle the possible state change
caused by invalidation requests propagated to the subtree during the short window. To allow fast checking of 
child state on the affected slot, in `MemReq` objects, the child cache also stores a pointer to the state variable
of the slot, and a value of the slot's state when the request is made. In `startAccess()`, we call `CheckForMESIRace()`
to determine whether the slot has been affected by concurrent invalidations or not. The return value of the function
indicates whether the current request should be processed as usual, or we should ignore the request just because
the request is no longer valid after the concurrent invalidation. This value will be returned to cache object's 
`access()` method. If the request is skipped (return value being `true`), the entire cache access will be skipped.

In `CheckForMESIRace()`, we compare the current state of the child cache's slot and the state when the request was initial
made. There are a few possibilities. If the request is a `PUTS`, and the invalidation just moves the slot's state to I,
then we do not need to perform the `PUTS`. If the request is `PUTX`, and the invalidation request moves it to 
state I, we also skip the request for the same reason. If, however, the invalidation request only downgrades the state to
S, we still need the request, but the request type is changed from `PUTX` to `PUTS` to reflect the state change.
For `GETX` requests, no matter how the state changes, we still need the `GETX` to bring the block into the cache in M
state. For `GETS` requests, there cannot be any invalidation, since `GETS` is only sent when the initial state is I,
which will not be changed at all by invalidation.

### Terminal Caches

The cache controller for terminal caches are simpler than middle level caches, since terminal caches do not have sharers 
list to maintain and hence do not have `tcc` objects. Invalidation lock is still present in `bcc`, since invalidation
from higher levels may still interfere with cache access. Correspondingly, in `startAccess()`, terminal caches only 
unlock the given `childLock` in the request object, and locks its own `bcc`. In `endAccess()`, `childLock` will be 
re-acquired before releasing `bcc`. 

Curious readers may naturally ask one question: who is the child cache of a terminal cache? As we will see in the next 
section, zSim also implements a virtual L0 direct-mapped cache as a "filter cache", the purpose of which is to reduce lock 
operations by reducing the traffic seen by the L1 terminal. 

## Filter Cache Optimization

Locking, no matter how lightweight it is made to be, will almost definitely incur a cache miss and memory fence when the 
lock is acquired due to the usage of atomic RMW instruction. In practice, we would like to avoid locking paradigm when the 
degree of contention is not high. To this end, zSim uses `FilterCache` to optimize out locking and unlocking on L1 caches
by exploiting the atomicity of 64 bit aligned memory operations as well as the locality of access, as we will see below.

### The Direct Mapped Abstract Cache

`class FilterCache` is implemented in file filter\_cache.h as a subclass of `class Cache`, inheriting the implementation
of `access()` without overriding it, but provides a slightly more complicated `invalidate()` which calls into the base class
`invalidate()` for the actual functionality. `class FilterCache` does not implement any new semantics for 
existing cache access methods, but instead, acts as a traffic filter to the underlying L1 internal states. Recall that
in order to access the tag array and state array within a cache object (there is no sharers list array in L1 cache), both 
`tcc` and `bcc` must be locked to guarantee a consistent view of these internal states. In the majority of cases, however, 
L1 accesses will result in a cache hit, which does not cause the state and the tag of the slot to change. If both the state
and the tag can be accessed read-only and atomically, no locking would be required, since the cache access transaction is 
trivially atomic.

The `FilterCache` objects are initialized in init.cpp, function `BuildCacheBank()`, called by `BuildCacheGroup()`, which
is further called by `InitSystem()`. In the top level function, boolean variable `isTerminal` determines whether the 
current cache object to be initialized is a terminal cache (that has no child) or not. If it is a terminal cache, then
in `BuildCacheBank()`, we instanciate `class FilterCache` objects instead if `class Cache` objects, and connect the 
filter cache to the processor's `l1i` and `lid`.

The `FilterCache` object adds a direct-mapped cache abstraction (which does not exist in the simulated hardware but just
for simulation performance reasons) on top of the set-associative L1 cache. The direct-mapped cache has the same number
of sets as the underlying L1 cache, but only one way for each set. Only the most recently accessed way in each set of
the L1 is stored in the L1's direct-mapped array. 

Each entry in the direct mapped array is called a `struct FilterEntry` object, consisting of three fields: A `rdAddr` field
indicating the most recently accessed line tag that we only have read permission; a `wrAddr` field indicating the most
recently accessed tag we have read and write permission, and `availCycle` indicating the cycle these blocks are available
in the underlying L1 cache. Note that `rdAddr` and `wrAddr` must either point to the same line, in the case of a recent
write, or having `wrAddr` being set to -1 to indicate that we do not have write permission to the most recently accessed
block, and hence a downgrade or fetch transaction must be started using the heavy-weight `access()` interface with the 
locking protocol discussed above. Compared to the standard "tag and state" approach of representing states of a cache 
block, using two tags allow us to encode both the state and the tag in only one variable: Read accesses only
check `rdAddr`, and write accesses only check `wrAddr`. On x86 platform, aligned 64 bit reads are always atomic, and 
therefore, we do not need to worry about concurrent invalidations while `FilterCache` is accessed, since the invalidation
must either serialize before or after the `FilterCache` access. Inconsistent intermediate states are guaranteed not to
be seen.

### Interfacing with Core Object

zSim treats filter caches as an extra level below the L1 cache, rather than within the L1 cache. The filter cache is 
write-through, in a sense that L1 block will be requested in M state when the filter cache misses. The core simulatior uses
`load()` and `store()` to access the filter cache for load and store uops respectively. In `load()`, we first compute the
set number as done in the regular cache object. We then read the `FilterEntry`'s member variable `availCycle`, and then 
read `rdAddr`. If the `rdAddr` matches the line address, filter cache is hit, and the larger one of `availCycle` and 
input argument `curCycle` (dispatch cycle of the load uop) is returned as the cache hit cycle. Note that it is entirely
possible for `availCycle` to be larger than `curCycle`, since the cache access is overlapped with uop issue and execution.
The current uop may read a block fetched by an earlier uop that will only be delivered to the L1 cache in the future after
the current uop is dispatched. In this case, the current uop is stalled in the load queue for roughtly 
(`availCycle` - `curCycle`) cycles before it commits. `store()` is handled similarly except that we compare the input 
line address with `wrAddr` rather than `rdAddr`.

Note that the order of reading the two member variables of `FilterEntry`, `availCycle` and the address tag `rdAddr`/`wrAddr`, 
is crucial. This is because we deliberately allow harmless race to happen here when an invalidation request is handled 
concurrently in the filter cache (`load()` and `store()` will not race with `access()` of the L1 cache, since only the 
current thread will access the L1 and the filter cache). In this case, both `rdAddr` and `wrAddr` will be reset to -1, 
indicating that no address will ever hit the filter cache. Loads and stores serialize with concurrent invalidations by 
the coherence order of the block holding the address tag on the host machine. In other words, the serialization order
of loads and stores with invalidations are determined by which of them accesses the address tag first. If loads
or stores access first, they should be serialized before the invalidation, with `availCycle` being a valid value.
If, on the other hand, loads and stores only access the address tag after invalidation, then `availCycle` is undefined, 
since logically speaking, the line is no longer in the filter cache and the L1 cache. If we read the address tag first
and `availCycle` later, a racing invalidation may invalidate the line between the two variable reads, in which case the 
address tag is read correctly, but `availCycle` is undefined. In practice, however, the invalidation routine does not
touch `availCycle` at all. The ordering of the two reads in fact makes little sense, contradicting what was said in 
`FilterCache`'s code comment. 

### Filter Cache Miss Handling

When `load()` and `store()` miss the filter cache, we call the underlying L1 cache's `access()` method and derive the
timing of the block. The call procedure is quite standard. In order to make the locking protocol happy, we define
a dummy MESI state in the stack, and include a pointer to that state in the `MemReq` object. The locking protocol
will access this dummy variable in `CheckForMESIRace()` and `class MESTBottomCC`'s `processAccess()`. For 
`CheckForMESIRace()`, the check will always pass without entering the if branch body, since filter cache 
races do not change this dummy state (we have other methods for dealing with that; see below). For `processAccess()`,
the state will be set accordingly, but we discard the value anyway, since filter cache encodes state and address
tag using `rdAddr` and `wrAddr` rather than traditional "tags and states". Furthermore, the member variable of filter 
cache object, `filterLock`, is passed as the filter cache's invalidation lock in the `MemReq` object. This lock
is passed in acquired state, and will be released by `startAccess()` immediately to allow pending invalidations
on the L1 to proceed (`filterLock` is first checked on L1 invalidation). After the underlying `access()` returns,
the `filterLock` will be re-acquired to block invalidations on the filter cache and L1 cache. The internal state
of both the filter cache and the L1 will be consistent until the filter lock is released. We also set the `rdAddr`
and `wrAddr` according to the type of the request. If the request is a write, then both tags are set, since we have
both read and write permission to the block in L1. If the request is a read, then only the read tag is set, since 
writes must incur a filter cache miss which is handled by the L1 cache object. `availCycle` of the `FilterEntry` object
is also updated. If the request is an upgrade request, indicated by the fact that the requested address is identical
to the read address tag (and write address tag must be -1), then we do not update `availCycle` for two reasons. First,
upgrade requests do not block later reads (reads will be forwarded from the store uop), so there is no need to stall
reads by updating `availCycle` to the completion cycle of the upgrade coherence transaction. Second, zSim serializes 
writes, such that the following store uop will not execute until the previous store uop commits. In this case, store
uops' timing will be determined by their commit cycle, and updating `availCycle` will not affect them.

### Filter Cache Invalidation

