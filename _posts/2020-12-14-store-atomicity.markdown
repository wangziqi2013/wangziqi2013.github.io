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
that are inserted into the cache on the remote core. 
