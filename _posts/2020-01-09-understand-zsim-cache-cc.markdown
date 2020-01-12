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

## 2PL in Cache Access

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


