---
layout: paper-summary
title:  "Filter Caching for Free: The Untapped Potential for Store Buffer"
date:   2019-08-05 16:51:00 -0500
categories: paper
paper_title: "Filter Caching for Free: The Untapped Potential for Store Buffer"
paper_link: https://dl.acm.org/citation.cfm?doid=3307650.3322269
paper_keyword: Store Buffer; Filter Cache
paper_year: ISCA 2019
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes using the store buffer as a small fully-associative cache to achieve less energy consumption and shorter load 
latency on modern architectures. Virtually all processors nowadays are equipped with a store buffer to hide the relatively 
slower coherence protocol. Without a store buffer, store instructions that are ready to commit otherwise must wait for the cache 
controller to acquire ownership of the cache block before the block can be updated. In a multi-chip architecture, this may 
take several hundreds of cycles in the worst case, which poses a great performance disadvantage as processors will stall and 
wait during this time.

To ensure the illustion of ordered execution, processors need to check not only the L1 cache, but also the store buffer, 
when a load instruction is executed. If a committed store with the same address as the load is found in the store buffer,
the processor either defers the commit of the load until the store is written into L1 (load-bypassing), or directly forwards 
dirty data just written by the store from the store buffer to the load instruction (load-forwarding). Note that although the 
store buffer plays an important role in the memory consistency model of the processor, whether or not loads are forwarded 
from stores do not affect the consistency model. For Sequential Consistency, load instructions must not commit before 
stores before it in the program order, i.e. they remain speculative in the load queue. When there is no aliasing in the 
store buffer, the coherence request is either made only after the store is committed, or speculatively made when the load is executed, 
and is squashed and replayed if the cache block is invalidated by another 