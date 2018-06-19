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
possibility that a "bad" line which does not enjoy much locality is evicted.