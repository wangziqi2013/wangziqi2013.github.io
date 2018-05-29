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

Lazy subscription, as its name suggests, enables  STM and HTM