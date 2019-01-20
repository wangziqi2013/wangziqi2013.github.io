---
layout: paper-summary
title:  "Delegated Persist Ordering"
date:   2019-01-19 04:33:00 -0500
categories: paper
paper_title: "Delegated Persist Ordering"
paper_link: https://ieeexplore.ieee.org/document/7783761
paper_keyword: Undo Logging; Persistence Ordering; NVM
paper_year: MICRO 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Delegated Persiste Ordering, a machanism for enforcing persistent write ordering on platforms
that support NVM. Persistence ordering is crucial to NVM recovery applications, because it controls the order that dirty
data is written back from volatile storage (e.g. on-chip SRAM, DRAM buffer, etc.) to NVM. For example, in undo logging, two
classes of write ordering must be enforced: First, the log entry must be persisted onto NVM before dirty items does, because
otherwise, if a crash happens after a dirty item is written back and before its corresponding undo log entry, there is no
way to recover from such failure. Second, all dirty items must be persisted before the commit record is written on the NVM
log. If not, the system cannot guarantee the persistence of committed transactions, since unflushed dirty items will be 
lost on a failure. 

Without significant hardware modification, in order to enforce persistence ordering on current platforms, programmers must 
issue a special instruction sequence which flushes the dirty cache line manually first, and then instruct the memory controller
to persist these writes. The instruction sequence, called a "sync barrier", is in the form of the following: 
clwb; sfence; pcommit; sfence;. The clwb instruction flushes back cache lines without giving up permissions for read. The 
line still remains in the cache in a non-dirty state after the instruction. The two sfences around pcommit prevents store 
operations from reordering with pcommit, which itself provides no guarantee of any ordering. The implication is that a 
persistence fence is also a store fence, since it blocks later store instructions from committing (i.e. being globally 
visible) until previous stores are persisted. The pcommit instruction tells the persistent memory controller to flush its 
memory queue such that all in-flight requests will become persistent before this instruction could retire. Note that 
recently, Intel announced that the pcommit instruction has been deprecated, because memory controllers are now considered 
as part of the persistence domain: On power failure, the memory controller is guaranteed to have enough power to drain 
its write queue before the system finally shuts down. With this convenience at hand, the pcommit instruction is no longer 
required for the persistence barrier, which now only requires a few clwb instructions and an sfence at the end.

Ideally, the persistence order would be identical to the memory consistency order (i.e. the order that memory operations 
become visible to other processors), such that programmers do not have to learn another set of reasoning rules for persistence 
order. This order is called Strict Persistency. In practice, enforcing this property using sync barriers (called "Strict 
Ordering", SO) introduces non-negligible overhead on several aspects. First, SO is overly restrictive, being that it also forces 
the processor to wait for the completion of persistence operations using pcommit (or clwb), which is not required in 
strict persistency. This is because currently the NVM controller write queue does not know the ordering requirement from
the processor, and hence may schedule operations in the write queue arbitrarily for better performance (e.g. taking advantage 
of inter-bank parallelism). Second, the pcommit instruction unconditionally stalls the processor until the NVM write queue 
is drained. If other applications in the system also writes to the NVM, pcommit has no way to know which operations belong
to which process or thread, and must wait for all of them. This is unnecessary if different applications run
different tasks in the same system. Finally, the clwb instruction is expensive. Dirty cache lines with exclusive permissions
will transit to shared state after the write back. On the next write operation to the same cache line, a coherence bus 
transaction must be performed to regain the exclusive permission, which introduces some extra latency on the critical path.
Besides, 