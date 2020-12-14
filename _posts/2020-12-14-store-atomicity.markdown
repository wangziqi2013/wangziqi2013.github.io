---
layout: paper-summary
title:  "Speculative Enforcement of Store Atomicity"
date:   2020-12-14 07:59:00 -0500
categories: paper
paper_title: "Speculative Enforcement of Store Atomicity"
paper_link: https://www.microarch.org/micro53/papers/738300a555.pdf
paper_keyword: Microarchitecture; LSQ; Pipeline; Store Atomicity
paper_year: MICRO 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Store and a forwarded load can be treated as a single memory operation (since no matter how external orders
   change, these two always have the same order, i.e., load is after store) when determining ordering. 
   This combination is not globally ordered when the store enters store buffer but has not yet been inserted into L1.
   Any local instructions, especially loads, executed after it are naturally ordered after the combination,
   but the combination can itself be ordered after remote operation, if the remote operation reaches the L1
   cache earlier than it.
   If the local load after the combination is itself ordered before a remote global operation, and the
   remote operation is ordered after the combination as described above, then a circular
   ordering can occur (see examples for details).

2. By putting a mark in the load queue, and prevent load operations to commit, we can stall loads in the ROB
   until the store that forwards value to load commits.

**Lowlight:**

1. What if there are multiple forwarding store-load pairs on different addresses? Are later loads are treated as
   speculative, or are forwarded loads start a new gate?

2. It seems that loads are still delayed, the ROB is still stalled. I might be wrong, but I cannot see any significant
   performance improvement this can bring us compared with stalling the forwarding load. Maybe there are some 
   overlapping between the draining of the store buffer, and the execution of the next load (as well as the gap between
   the forwarded load and the second load).

This paper proposes a microarchitectural improvement for enforcing store atomicity. Store atomicity, as the paper
shows in later sections, if violated, can make the processor vulnerable to a class of memory consistency problems
that leads to non-serializable global ordering.
Modern processors, unfortunately, often implement the memory consistency model without store atomicity, or only a 
weaker version of it, called "write atomicity", which can incur the same problem as non-store atomicity systems.
Some systems may implement store atomicity, but do so at the cost of longer read latency and hence lower 
overall performance.
The paper, therefore, first identifies the source of non-serializable memory ordering of non-store atomic systems, 
and then proposes a lightweight mechanism implemented in the load store unit (LSU) to turn a non-store atomic
system into one.
The resulting system both enjoys the convenience of a more intuitive memory consistency model, and preserves short
load latency.

This paper assumes a x86-like memory consistency model and implementation, which we discuss below. The x86 implements 
Total Store Ordering (TSO) without store atomicity. Memory accessing instructions are translated into load and store
uops (and potentially other uops), and inserted into the ROB. In the meantime, these uops are also inserted into
special stuctures called the load queue and the store queue. Load and store queues track the address (and other
status bits) of the uops, which are used by later uops to enforce correct program order, as uops are issued
out-of-order.
When store uops in the store queue are ready, i.e., both address and data are generated, the uop will commit in the 
ROB, when it reaches the head of ROB, and then be moved to the store buffer (SB). Retired uops in the store buffer
are then inserted into the L1 cache by invoking coherence, using the store buffer as a temporary buffering space to
avoid stalling the pipeline when coherence is busy.
In practice, the store queue and the store buffer are often implemented as a single physical structure, with a pointer
delimiting the boundary.
When a load uop is executed, the load circuit should first check whether an older committed uop of the same address is 
already in the store buffer (and also store queue, but this is not the focus). If so, the value should be forwarded
from the store buffer directly, such that program order is observed.

The paper, however, observes that simply forwarding a value from the store buffer to a load uop may cause memory 
inconsistency problems, as the local core sees the value earlier than remote cores. This is because after store uops
retire, and before they are inserted into the cache by invoking coherence, the store uop has not been inserted into
the global ordering, which is impossible for remote cores to observe, naturally ordering it after all memory operations
that are inserted into the cache on the remote core. On the other hand, with store forwarding, local load uops can
conveniently read the value of the store, before a remote core issues its own reads and writes into the cache, which
essentially orders the write uop before the remove operation, which is established via a second load (to a different
address) that reads forwarded value, since the second load cannot observe a remote core's write, but the first already sees the local store. 
Conflict will be observed, if the store uop is ordered both before and after some remote operation.

The paper gives two examples. In the first example, The second load does not observe a remove write to the same 
variable as the second load, hence being ordered before the remote write. Then the remote core executes a second
store, which is on the same address as the local core's store, and is inserted into the cache before the local
store (which is totally possible, since store buffers on different cores are in no way synchronized). In this case,
two conflicting orders occur. On one hand, the store is ordered after the remote core's second store, since the
final memory value on the address is the local core's store. On the other hand, the store is ordered after the 
remote core's second store, since the first load observes the local core's value, the second load is order
after the first load by program order, which is itself ordered before the first remote store, since it does
not observe the value of the store. The remote stores are themselves ordered by program order, and therefore, the 
local store is ordered before both of the the remote stores, a conflict.

In the second example, the second local load did not obseve the remote store, and the remote core later execures
a load to the local store's address, and also does not observe the local store, since the local store has not
been inserted into the cache. In this case, the local store is ordered both before and after the remote load.
On one hand, the since the remote load does not observe the local store, indicating that the latter is ordered after
the former. On the other hand, the second local load is ordered before the remote store, which is itself ordered
before the remote load. Given local program orders, it indicates that the local store is ordered before the remote
load, also a conflit.

Alternative implementations of the store buffer and load forwarding mechanism may choose not to allow forwarding, or
only commit the load operation once the store has been inserted into the L1 cache, after which the ordering
of both the store and load can be established. 
This approach, however, degrades performance, since it essentially
requires the load to wait for cache coherence on an entirely unrelated address, which increases load latency. Since
loads are often on the critical path, this can negatively impact performance.

The paper later summarizes that the major cause of a non-atomic store is because the local core executes a second
core after the first one, before the store has been inserted into the cache. If the second store is only executed after 
the store has been globally visible, then the above two cases will never occur, since all operations are ordered by the
real-time order they invoke coherence.

To address this issue, the paper proposes that the commit of the second load should be delayed until the store is
inserted into the L1 cache. To achieve this, when a store-load forwarding happens locally, and the store uop
has not been inserted into the L1 cache when the forwarded load commits, the pipeline control
logic sets a special bit in the load queue, indicating that the next load (and all loads after, since loads are not
reordered) should stall until the forwarding store is globally visible. The current location of the store uop
in the store buffer is also stored in an extra register of the load queue. Whenever a store uop is drained,
the load queue checks whether the store uop matches the current value of the register. If true, then the load queue
can be unblocked, and the head entry can commit in the ROB. Otherwise, the load queue keep being blocked.
