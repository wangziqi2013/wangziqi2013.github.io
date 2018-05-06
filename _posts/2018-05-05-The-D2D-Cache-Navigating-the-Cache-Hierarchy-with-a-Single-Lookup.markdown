---
layout: paper-summary
title: "The Direct-to-Data (D2D) Cache: Navigating the Cache Hierarchy with a Single Lookup"
date: 2018-05-05 21:25:00 -0500
categories: paper
paper_title: "The Direct-to-Date (D2D) Cache: Navigating the Cache Hierarchy with a Single Lookup"
paper_link: https://dl.acm.org/citation.cfm?id=2665694
paper_keyword: D2D Cache; TLB
paper_year: 2014
---

This paper presents an elegant solution for solving the problem of having to probe all levels of 
the cache when a miss to DRAM occurs. Essentially this is totally unnecessary and wastes cycles. The 
problem we have here is that L1 cache is not sufficient to tell whether a cache line will miss the next level,
either L2 or L3. The status of miss or hit in lower levels will remain unknown before these caches are
probed. To solve the problem, instead of having the processor probe L1, L2 and L3 caches in a row (which 
is unnecessarily serialized), the exact location of a line is stored in the TLB. Every time a virtual address
is translated, in addition to finding the physical address associated with an entry, the TLB also 
returns the location of the line, including its cache level and set ID. Indices are always extracted from
the virtual or physical page number depending on whether the cache is virtually or physically indexed.

Two extra components are added in D2D design. First, the TLB must be extended (called the "eTLB") to contain
location information of cache lines. Two bits are needed to represent the cache identity, assuming three level of caches.
The number of bits for set ID depends on the maximum associativity among all levels. The paper uses 4 bits to accommodate for 
the 16-way set associative L3. The second componeng is called a "Hub", and it maintains the identity of all cached data
in all levels. 

The Hub is a physically indexed and physically tagged lookup structure private to processors.
We maintain the invariant that if the information of the cache line is not in the Hub, then the corresponding cache 
location must also be evicted.
Although the paper did not elaborate on the way the Hub is structured, attention should be paid because the Hub cannot diacard 
cache line location information without evcting the cache lines. 

Regular cache line tags in D2D design are removed, and replaced with a pointer to Hub entries. This 
also makes the tag array shorter, because pointer to the Hub is actually shorter than a tag. Each Hub entry also has 
a pointer to eTLB, indicating that the entry is cached by upper level TLBs. This pointer is set to none if eTLB
does not have a copy. eTLB entry points to the cache entry using cache identity and set ID as previously stated. 
The cycle enables very flexible handling of events. No matter which component in the 
system generates an event that require all three components to collaborate, it can always be handled by traversing
the cycle and synchronize them. 