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
hardware transactions, such that both can inform each other of their state changes. 

One example of exploiting lazy subscription is Hybrid NORec, where both types of transactions use a commit counter
to serialize write phases. In the normal operation mode, STM atomically increases the counter to perform write back, 
and then atomically increments the counter to indicate the completion. Hardware threads, on the other hand, subsribes 
to the counter at the beginning and spin loop until no STM is committing. At commit time, the hardware thread increments 
the commit counter by two to indicate an atomic commit. STM monitors the content of the counter on every read operation.
If the counter has changed since last time it was sampled, then at least one transaction must have committed, potentially
overwriting the current transaction's read set. In this case, the current transaction performs a value-based validation,
and aborts if the read set is indeed invalid.