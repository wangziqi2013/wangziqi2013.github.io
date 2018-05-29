---
layout: paper-summary
title: "Hardware Extensions to Make Lazy Subscription Safe"
date:   2018-05-29 03:07:00 -0500
categories: paper
paper_title: "Hardware Extensions to Make Lazy Subscription Safe"
paper_link: https://arxiv.org/abs/1407.6968?context=cs
paper_keyword: Hybrid TM
paper_year: arXiv 2014
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Hardware Lock Elision (HLE) is a technique that allows processors with transactional memory support to
execute critical sections in a speculative manner. The critical section appears to commit atomically at the 
end of the critical section. This way, multiple hardware transactions can execute in parallel, providing higher
degrees of parallelism given that the transactions do not conflict with each other.

Due to certian restrictions of current commercial implementations of HTM, HLE mechanisms must provide a "fall-back" 
path that executes the critical section in pure software with minimum hardware support. This is usually caused by the 
fact that HTM capabilities heavily depend on the capacity of the cache and cache parameters. If the size of a transaction
exceeds the maximum that the cache could support, then there is no way that the transaction can commit even
in the absence of conflict. The fall back path must therefore be able to interoperate with hardware transactions in a 
transparent way. On Intel platform, the fall back path let the transaction acquire and release the lock as it would be 
without HLE. Hardware transactions must "subscribe" to the cache line that contains the lock by reading its content at
the beginning of the transaction. Hardware transactions can only start if the lock is currently free. If a fall back
transaction acquires the lock by writing into the lock, then all hardware transactions must be aborted. This is 
necessary to prevent them from reading inconsistent states created by the fall back transaction before they are 
actually aborted by data conflicts.

Lazy subscription, as its name suggests, is a scheme that allows hardware transactions to subscribe to the lock
"lazily". This means that the subscription needs not to happen at the beginning of the transaction, but right before 
the transaction is ready to commit. Lazy subscription is sometimes favored over standard HLE, because it allows higher 
degree of concurrency between hardware threads and the fall back thread. Standard HLE, as described in the previous 
paragraph, serializes the execution of hardware transactions and fall back transactions. At any given point in time,
only one type of them can be actively running. This, however, is unnecessarily restrictive, because hardware transactions
and fall back transactions can of course commit in parallel as long as they do not access conflicting data items. To exploit
this extra opportunity, HLE with lazy subscription must have a two-way communication mechanism between fall back and 
hardware transactions, such that both can inform each other of their state changes. This signaling mechanism does not 
yet exist in standard HLE. We will see an example below that implements the feature.

One example of exploiting lazy subscription is Hybrid NORec, where both types of transactions use a commit counter
to serialize write phases. In the normal operation mode, STM atomically increases the counter to perform write back, 
and then atomically increments the counter to indicate the completion. Hardware threads, on the other hand, subsribes 
to the counter at the beginning and spin loop until no STM is committing. At commit time, the hardware thread increments 
the commit counter by two to indicate an atomic commit. STM monitors the content of the counter on every read operation.
If the counter has changed since last time it was sampled, then at least one transaction must have committed, potentially
overwriting the current transaction's read set. In this case, the current transaction performs a value-based validation,
and aborts if the read set is indeed invalid. As a contrast, with lazy subscription, hardware transactions only subscribe to
the commit counter at the end of the transaction, right before it is going to execute the commit instruction. The 
subscription of the commit counter synchronizes with the atomic increment operation performed by STM. The order of 
HTM and STM transactions are determined by the order that corresponding primitives are executed.

One problem with lazy subscription is that HTM transactions may read inconsistent values, because they can begin
in the middle of a software transaction's write back (the lock is not checked at the beginning), or because STM can 
begin and perform partial write back in the middle of the HTM transaction. Either of these may lead to incorrect execution 
where the snapshot that the hardware transaction depends on can never occur in a serialized execution. The inconsistent 
snapshot will finally be discovered by the HTM when STM write back completes, because it is a write-after-read conflict, and 
all current HTM implementations will abort. The problem, however, is that before this can ever happen, inconsistent data
may be used to switch the control flow via indirect jump, or to decide the address of the lock to be subscribed, or to 
determine the value of the lock state. It is possible that the hardware transaction be tricked into executing wrong 
code, or reads the wrong lock, or even corrupt random memory addresses. Essentially, execution of the hardware transaction 
is undefined.

To counter such problem, hardware transaction must have an error discovery and self-abort mechanism when it detects that
the execution may become undefined due to inconsistent reads. One obvious solution, used by Hybrid NORec, is to 
validate every hardware load instruction. The validation spins on the current commit counter lock bit using 
non-transactional load, and waits for the ongoing write back phase, if any, to complete. If the read becomes inconsistent 
due to reading partially committed data, waiting for the write back to complete will guarantee that the hardware can at 
least detect the conflict and then abort. Simple as it is, this solution has two undesired properties. The first is that 
hardware transactions need to be instrumented, extending every load operation with a validation. The second property is 
that spinning itself is an inefficient way of synchronization, which may cause frequent cache line invalidation. 

The paper proposes another solution by adding two registers. One register, the lock address register (LAR), stores the 
lock address, and is loaded as the transaction begins. The purpose of this register is to maintain a reference 
to the lock before the execution becomes potentially undefined. Another register, the Subscription Code Address
Register (SCAR), is loaded with the function pointer that subscribes to the lock in a similar way. Once these two registers 
are loaded at transaction begin, they cannot be altered until the transaction commits or aborts. During the execution
of the transaction, any attempt to modify these two registers will cause the transaction to abort immediately, because 
this implies that undefined execution has occurred. If the transaction executes the commit instruction, either intending to
commit or as a result of undefined execution, the SCAR function pointer is called with LAR to check the 
value of the lock and then subscribe from it. As long as LAR and SCAR are loaded with correct values, no matter whether 
or not the the execution is undefined, the transaction can always subscribe to the correct lock, or be aborted as 
a consequence of undefined execution.

There remains one issue with the above solution. We assume in the above discussion that the code section of the SCAR 
function pointer and the lock to be subscribed will be consistent. Nothing, however, could prevent the undefined execution 
from overwriting the lock pointed to by LAR, or code pointed to by SCAR. Fortunately, if the overwrite truly happens, then 
they must exist in the transaction's write set. We use a lazy approach to discover whether this has occurred. It works 
as follows. After the transaction reaches the commit instruction, it enters a special mode, where any attempt to execute 
or read/write data items in the write set will cause an immediate abort. Since both the lock and the function to subscribe 
from the lock should not be touched by the transaction, if they are overwritten by the transaction, then it must be 
the case that undefined execution made them so.