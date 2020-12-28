---
layout: paper-summary
title:  "Relaxed Persist Ordering Using Strand Persistency"
date:   2020-12-27 21:19:00 -0500
categories: paper
paper_title: "Relaxed Persist Ordering Using Strand Persistency"
paper_link: https://ieeexplore.ieee.org/document/9138920
paper_keyword: NVM; Write Ordering; Strand Persistency; StrandWeaver
paper_year: ISCA 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes strand consistency and a hardware implementation, StrandWeaver, to provide a better persist 
barrier semantics and a more efficient implementation than current designs. Persist barriers are essential to NVM
programming as it orders store operations to the device, which is utilized for correctness in many logging-based 
designs. For example, in undo logging, log entries must reach the NVM before dirty data, and dirty data must be flushed
back before the commit mark is written. Similarly, in redo logging, redo log entries must be ordered before the commit
mark, which is then ordered before all dirty data.
On today's commercial architectures, these write orderings are expressed as persist barriers consisting of cache line
flush and memory fences. For example, on x86 ISA, a persist barrier consists of one or more clwb instructions for 
writing back dirty cache lines, and a sfence instruction after all clwbs.
clwb instructions are only strongly ordered with preceeding store instructions with the same target address, and memory
fence (either explicit or implicit) instructions. clwbs are neither ordered with other stores nor with each other.

The paper points out that a persist barrier implementation in the above form has two performance drawbacks. First,
persistence ordering is coupled with consistency ordering, meaning that the pipeline must be stalled before a dirty
block is fully flushed back to the NVM, blocking the commit of the following store operations even though these stores 
do not write into the NVM. Second, parallelism is severaly restricted, since only one or a few write operations can
be persisted in parallel before the sfence instruction due to the property of most NVM-related workloads. 
Current commercial NVM devices usually have a few persistence buffers internally, which supports multiple concurrent
operations for better throughput.

To address the above issues, this paper proposes strand persistency model, which relaxes some overly restricted ordering
requirements in today's persistence model, and enables a new programming model for writing NVM applications.
In the conventional persistence model, the execution or stores and cache line write backs are divided into "epochs"
by the store fence instructions. Store operations in the same epoch are unordered, but store operations on different 
epochs are guaranteed to be in the program order. Besides, memory persistency order is fully coupled with consistency
order, meaning that store operations must not proceed in the pipeline before all persistent stores are completed. 
The above model is called "epoch persistency" in previous publications, which incurs large performance overhead on 
current architectures.
In strand persistency, two changes are made over epoch persistency for better performance and parallelism.
First, applications can start and close "strands" of persistence regions, which are independent from other strands, 
unlike in the epoch model where completion of stores in later epochs always depent on persistence of stores on earlier 
epochs. Instead, stores in different strands do not depend on each other, and can therefore be persisted in parallel.
Second, strand persistency decouples persistency from memory consistency, meaning that store operations are no longer
stalled in the store buffer even if a previous store divided by an intra-strand barrier in the same strand has not been 
persisted yet. This allows some degrees of overlapping between L1 coherence actions of the following store and 
persistence of earlier stores, which both reduces the cycle overhead of NVM writes, and let store operations release
the store buffer faster for higher write throughput and less resource hazards.

The paper proposes three hardware primitives for applications to take advantage of strand consistency. The first 
primitive, NewStrand, starts a new strand since its location in program order, dropping all previous ordering 
dependencies. All store and barrier operations are considered as in the new strand unless another NewStrand primitive
is seen. Note that for simplicity, strands must be a consecutive range of stores and other barrier primitives in the 
dynamic instruction trace. 
The second primitive is persist barrier, which acts as an ordering barrier within a strand. Write operations within the 
strand must be properly ordered, such that writes after the barrier will not be persisted earlier than writes before
the barrier does. Note that the barrier does not define the memory consistency order of writes before and after. Write
operations can be drained into the cache hierarchy regardless of the persistence order enforced by strands and barriers.
Store operations in different strands are not affected by the barrier in any of the strand.
The last primitive, JoinStrand, serves a similar purpose as the join() call in conventional process and thread 
libraries. When executed, this instruction stalls the execution of the following stores, clwbs and barriers
until all previous stores in the program order have been persisted. 

The paper assumes the following baseline architecture. The instruction set is x86, with stores and clwb in the current
form. The above three primitives are also added into the ISA. The memory consistency model is TSO, with a FIFO load 
queue and store queue for enforcing load-load, store-store ordering, and store-load forwarding. 
Store operations are inserted into the store queue when in also entered the ROB, until commit time after which the 
address and source operand have been computed. Commited stores are moved to the store buffer, which essentially are
part of the memory image, but have not been inserted into the cache hierarchy and hence remain invisible to all
cores except the one generating them (this property is called "store atomicity").
The ordering properties between clwbs and stores are also identical to the current x86: clwbs are only ordered with 
stores on the same address, but clwbs are not ordered with other stores or clwbs.
Although the paper did not clarify the ordering properties or the three primitives, it is most likely that they are 
all strongly ordered with stores and clwbs to avoid complicated reordering scenarios.

The paper proposes adding two extra hardware structures in the core backend for implementing strand persistency.
The first structure, called the persist queue, orders stores in the store buffer and clwbs to ensure proper 
ordering of stores and write backs. In addition, it controls the creation and join of strands. 
The second structure, called the strand buffer, is an array of individual buffers for enforcing ordering within a 
single strand. Each logical strand is mapped to a strand buffer instance, and stores within the same strand are 
controlled by write backs and persist barriers within the same strand.

We next describe the structure of the persist queue. Cache line write backs and the three primitives are all inserted
into the persist queue as they enter the ROB. Each entry of the persist queue contains three control bits: Valid,
can_issue, issued, and completed. 
An entry contains a valid instruction if the valid bit is set. The can_issue bit is set for clwbs
and persist barriers, if they are ready to be issued into the strand buffer. After being issued, instructions remain
in the persist queue with issued bit set, until they are completed, after which the completed bit is set. 
The persist queue retires instructions in-order after the completed bit is set.
For clwb instructions, an extra address field stores the cache line address. The persist queue can be used as a large
CAM for address searching. A hit is signaled if the requested cache line address matches any of the entries, and 
the index of the entry as well as the index in the ROB is returned.

The persist queue operates as follows. When a clwb instruction is inserted, it performs an associative lookup on
the store buffer. If the store buffer contains a store of the same address, the clwb is stalled by not setting the
can_issue bit. This is to avoid reordering between clwbs and a preceeding store of the same address. Otherwise, the
can_issue bit is set.

