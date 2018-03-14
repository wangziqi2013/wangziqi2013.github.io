---
layout: paper-summary
title:  "Transactional Conflict Decoupling and Value Prediction"
date:   2018-03-14 17:12:00 -0500
categories: paper
paper_title: "Transactional Conflict Decoupling and Value Prediction"
paper_link: https://dl.acm.org/citation.cfm?id=1995904
paper_keyword: DPTM (Decoupling and Prediction TM); Value Prediction; Validation
paper_year: 2011
rw_set: L1 for RS; Write buffer for WS
htm_cd: Mostly Lazy; Based on prediction
htm_cr: Mostly Lazy; Based on prediction
version_mgmt: Lazy
---

This paper proposes DPTM, Decoupling and Prediction TM, that reduces abort rates of classical SS2PL based best-effort HTM
by delaying read validation till commit time, turning preemptive SS2PL partially into OCC. The argument is that cache 
line invalidation does not necessarily mean logical conflicts. They can be artificially caused by false sharing, or silent stores. 
(i.e. one or more stores that do not change the final state), or doomed transactions (i.e. transactions that eventually aborts). 

DPTM maintains fine grained read sets in cache tags. It also adds a new "present but invalid", or "Stale" state to differentiate cache 
lines that have been transactionally loaded but invalidated with cache lines that are not present (the old "Invalid" state). 

On transactional load instructions, DPTM marks read set bits on the finer granularity. If the load address hits a Stale
cache line, DPTM predicts whether it should abort. If prediction favors not aborting, then the Stale cache line is used
to fulfill the load instruction, without re-acquiring the line. The value loaded using prediction must be recorded 
for later validations.

On transactional store instructions, DPTM buffers the addresses and data in the store buffer. On cache line invalidation requests, if 
they hit transactionally loaded cache lines, DPTM always acknowledges them. Instead of turning the line into "Invalid" state, the line 
will stay in "Stale" state, keeping tag, data and read set bits intact. **There is no transactionally written lines,
as DPTM uses a separate store buffer.**

On pre-commit, DPTM must first lock the entire read and write set, and then validate the read and write set. All invalidation 
requests are NACKed after a transaction enters pre-commit stage. If a transaction receives NACK as the response during
transactional execution, it must abort.

The read set validation proceeds as follows: for all Stale cache lines, read-shared
permissions are re-required. After the cache line is received, DPTM verifies that the value it predicts are correct.
If all Stale cache lines fails validation, the transaction must abort. If read set validation passes, then for each address whose cache line has not been in the exclusive state in the processor's L1 cache, 
the cache controller sends a read-exclusive message to the bus or the directory. DPTM then applies speculative changes onto
the cache line. Note that it is possible to receive NACK during both read and write set validation. 

After pre-commit, all transactionally loaded and stored cache lines are in the processor's L1 private cache. 
An atomic in-cache commit is then performed as in the classical HTM. 

A few optimizations are possible. One of them is to send the transaction's read and write set along with coherence requests
as a bitmap (signature?). This may help the receiver to eagerly determine that a prediction is not feasible, and hence 
abort early to avoid wasted cycles. (*I am confused here. Why sending the read set? There is even no invalidation for transactional 
written lines*). The second optimization prposes enhancing existing cache coherence protocol to support updating values in another 
processor's cache. If this is supported, a committing transaction could broadcast its changes to a cache line to all other processors that have a Stale line. The latter then updates the content of Stale lines, which may help improving the accuracy of prediction.