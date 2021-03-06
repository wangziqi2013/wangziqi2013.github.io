---
layout: paper-summary
title:  "Clobber-NVM: Log Less, Re-execute More"
date:   2021-05-09 17:17:00 -0500
categories: paper
paper_title: "Clobber-NVM: Log Less, Re-execute More"
paper_link: https://dl.acm.org/doi/10.1145/3445814.3446722
paper_keyword: NVM; Clobber Logging; iDO; JUSTDO; Semantics Logging; Resumption
paper_year: ASPLOS 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. Using semantics logging to record function name and arguments before transaction begin such that the transaction
   can be re-executed on a crash.

2. The semantics logging is optimized such that: (1) Read-only objects (or object fields) on the NVM are not 
   logged since their values are still accessible after crash; 
   (2) Only non-volatile object fields that are actually modified by the transaction are undo-logged with the
   assistance of compilers, i.e., demand undo-logging on function arguments rather than write set (which is 
   just a function of function name and arguments).
   This allows us to restore the original value of the arguments before re-executing the transaction body.

3. It is essentially an optimization over iDO logging by transforming the entire transaction body to an
   idempotent region. The transformation undo-logs persistent arguments that will be modified in the body,
   such that the transaction can always be re-executed without affecting the argument value, as these values
   will be restored by replaying the undo log first.

4. Use compiler's data flow and aliasing analysis to statically identify persistent object fields that are to be
   modified during the transaction, and insert undo instrumentations accordingly.
   This avoids maintaining a dynamic hash table at run time for the write set.
   But, if compiler analysis is not available,  using a run time hash table is still an option.

**Questions:**

1. Does register-passed arguments count as volatile inputs? How do programmers issue commands to persist these
   inputs? I suppose the compiler should detect register-passed arguments, and logs them automatically at 
   transaction begin.

2. Does stack variable count as volatile inputs? I guess that depends on whether the stack is allocated on the   
   NVM or DRAM, but it seems that Clobber NVM uses DAX mode for NVM rather than mapping the whole address space
   to the NVM, so the stack is not on the NVM. In this case, the compiler should also recognize it and
   automatically persists these inputs.

3. The paper lacks a mechanism for log trimming. The log can only be trimmed after all persistent states of 
   a transaction is written back to the NVM.
   It seems hard to track this.
   One simple way is to flush all dirty data back to the NVM at transaction commit, and trims the log immediately.
   The paper seems to suggest this, since it says that the undo logs are managed by PMDK and that PMDK will
   flush dirty data at transaction commit as per undo logging protocol.
   Also the paper implies that there is only one log object per-thread, meaning that the log has to be trimmed
   at every transaction commit.
   But the authors should really have said that explicitly.

This paper presents Clobber-NVM, a transactional framework for Non-Volatile Memory using recovery-via-resumption.
The paper noted that previous undo or redo logging-based schemes are inefficient, since they need to persist all 
memory writes performed on persistent data. This essentially doubles the amount of traffic to the NVM device.
In addition, if redo logging is used, reads must be redirected to the log in order to access the most up-to-date data.
The paper also noted that previous recovery-via-resumption methods, such as JUSTDO logging and iDO logging,
both have their problems.
JUSTDO logging requires a persistent cache hierarchy which is not yet available, and will likely not be 
commercialized in the future. It only saves the address, data and program counter of the most recent store 
operation in a FASE, without having to maintain a full log. On crash recovery, the machine state is immediately
restored to the point where the last store happens, and the execution of the FAST continues from that point.
It is essentially just an optimization for persistent cache architecture.
iDO logging, on the other hand, divides the FAST into consecutive "idempotent" regions with compiler assistance. 
Each idempotent region is guaranteed to produce the same result given the same inputs (i.e., they do not modify the 
inputs). 
Semantics logging is then performed at a per-idempotent level by persisting the inputs (which are usually outputs
from the previous region, and can be on either register or stack) and program counter of a region when it is about 
to be executed. 
Recovery can hence be performed by loading the the most recently logged region input argument back to the register
and stack, and resuming execution from that idempotent region. 

Clobber NVM adopts the idea of iDO logging, and optimizes it by writing semantics logs at the granularity of whole 
transactions, rather than only idempotent parts of a transaction.
Compared with iDO logging, it does not require logging each individual idempotent regions, but rather, it makes 
the entire transaction idempotent by undo-logging input values that will be modified in the transaction.
Recovery is therefore preformed in two stages. In the first stage, the undo log is replayed on the input value
such that they are restored to the states before the transaction began. 
In the second stage, iDO-style recovery is performed by loading the input values of the transaction to 
register file and the stack, after which the transaction is re-executed from the beginning by jumping to the 
logged program counter.
Compared with previous semantics logging approaches, where the input arguments are logged before the transaction begin,
and a transaction is replayed by always re-executing it with the logged input parameters, Clobber NVM
does not need to save all input values at transaction begin. In fact, only those that will be modified will be
undo logged. This can sometimes greatly reduce the amount of input parameters to be logged, especially if they are
pointer-based structures ("demand logging").
In addition, previous semantics logging designs combine word-level redo-logging with semantics logging. The former
is used for background replay of the logs to keep the NVM image consistent with the current logical image 
(which is usually held in a DRAM buffer), while the latter is used for quick commits, since a transaction is 
considered as commit once its semantics log is persisted.
This combination prioritizes commit latency over write amplification, while Clobber NVM reduces both.

We next elaborate the operations of Clobber NVM in more details. As have stated earlier, Clobber NVM assumes
a transactional interface, where the programmer specifies the begin and commit point of a transaction, and
the framework guarantees that all memory operations within the transaction are either performed, or none of them
is performed.
Isolation is implemented with conventional 2PL in the transactions: Programmers are responsible for locking 
data items before they are accessed, and locks are only released after the commit of the transaction. 

At transaction begin, in addition to locking all data items to be accessed in the transaction body, the 
programmer is also responsible for persisting volatile inputs (arguments to the transaction body function) that 
will be accessed during the transaction using the `vlog_preserve()` macro. This is necessary, since otherwise 
these volatile inputs would be lost after a crash, making re-execution impossible. 
Besides, the name of the function and the argument mapping (where to find arguments and how many of them) are also
persisted.
After all the above steps complete (followed using a persist barrier), the transaction is considered as
already committed despite the fact that it has not started execution, as all information for re-execution has been
stored on the NVM.
An `active` bit in the per-thread log is set to indicate this, such that the recovery handler will treat the 
transaction as committed, and replay it on crash recovery.

During transaction execution, whenever an input object allocated on the NVM is to be modified by the 
transaction body (via a pointer), an undo log entry is first generated and persisted to a per-thread log buffer area.
The modification of NVM objects are detected by compiler passes, as we will see below. 
No other data logging is performed in the transaction body.
At the end of the transaction, all dirty data items that belong to the NVM are flushed back. This 
physically commits the transaction, and after the commit point, the log entry can be invalidated by clearing the 
`active` bit mentioned earlier.

The paper then proposes a compiler analysis mechanism for statically detecting modifications on persistent input  
values.
The compiler analysis detects the pattern where an input object (or more likely, a field of it) is written after
it is first read. It then inserts call back functions to generate undo-log entry with the pre-value, followed by 
a persist barrier.
If, however, the object is written before being read first, then the write need not be logged, 
since what the transaction sees is the value written by itself, rather than the original input object's value.
Furthermore, if a value is written more than once during the body, which most likely happens in a loop, then only
the first write is logged, since later writes just overwrite the value generated by the transaction itself.
