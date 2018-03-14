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
by delaying read validation till commit time, turning preemptive SS2PL partially into OCC. DPTM maintains fine 
grained read sets in cache tags. It also adds a new "present but invalid", or "Stale" state to differentiate cache lines 
that have been transactionally loaded but invalidated with cache lines that are not present (the old "Invalid" state). 

On transactional load instructions, DPTM marks read set bits on the finer granularity. If the load address hits a Stale
cache line, DPTM predicts whether it should abort. If prediction favors not aborting, then the Stale cache line is used
to fulfill the load instruction, without re-acquiring the line. The value loaded using prediction must be recorded 
for later validations.

On transactional store instructions, DPTM buffers the addresses and data in the store buffer. On cache line invalidation requests, if 
they hit transactionally loaded cache lines, DPTM always acknowledges them. Instead of turning the line into "Invalid" state, the line 
will stay in "Stale" state, keeping tag, data and read set bits intact. Invalidations on transactionally written lines should cause an 
immediate abort as usual, because for recoverability reasons, HTM must not leak uncommitted data. 

On commit, DPTM must first lock the entire write set, and then validate the read set.
For each address whose cache line has not been in the exclusive state in the processor's L1 cache, the cache controller
sends a read-exclusive message to the bus or the directory. Once exclusive permission is acquired, it NACKs all 
incoming requests for the cache line. DPTM then performs value validation. For all Stale cache lines, read-shared
permissions are re-required. After the cache line is received, DPTM verifies that the value it predicts are correct.
If all Stale cache lines pass value validation, the transaction could perform an in-cache commit. Otherwise, validation
fails, and the transaction must abort.