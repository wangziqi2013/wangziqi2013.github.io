---
layout: paper-summary
title:  "The V-Way Cache: Demand-Based Associativity via Global Replacement"
date:   2018-06-18 22:57:00 -0500
categories: paper
paper_title: "The V-Way Cache: Demand-Based Associativity via Global Replacement"
paper_link: https://ieeexplore.ieee.org/document/1431585/
paper_keyword: LLC; V-Way Cache; Global Replacement
paper_year: ISCA 2005
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Fully associative cache has the least number of cache misses and hence the 
best performance when compared with a set-associative cache of the same size. Two factors
contribute to the superiority of full associativity. First, a fully associative cache do not 
force a cache eviction as long as the cache has not been filled up yet. This reduces the 
number of conflict misses. On the contrary, evictions are mandatory for a set-associative cache if all cache lines
in a set has been occupied, regardless of whether empty lines exist in other sets. Second, even if the 
cache is full, a fully associative cache can evict any of the lines currently in the cache, maximizing the 
possibility that a "bad" line which does not benefit from extra locality is evicted. For a set-associative 
cache, however, an eviction must be made within the set that the missed line will be loaded. Given that the 
number of ways in a typical cache is usually significantly smaller than the total number of lines, it is likely 
that the decision is sub-optimal. In the following discussion, eviction decisions made by considering all lines 
in the cache is called "global replacement", while decisions made only within a certain set is called "local replacement".

Increasing the associativity of a cache or simply using fully associative cache, according to the results reported 
by the paper, can increase the hit rate. The extra cost and hardware changes, however, may not justify the performance
improvement. One problem with large associativity is the cost of extra data store, as the number of tags in each
way must equal the number of blocks allocated to that way. Furthermore, the latency of tag comparison, which is on
the critical path of memory instructions, increases as the number of tags to compare increase. This implies larger 
hit latency