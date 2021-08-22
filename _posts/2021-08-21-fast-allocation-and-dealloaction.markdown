---
layout: paper-summary
title:  "Fast Allocation and Deallocation of Memory Based on Object Lifetimes"
date:   2021-08-21 20:30:00 -0500
categories: paper
paper_title: "Fast Allocation and Deallocation of Memory Based on Object Lifetimes"
paper_link: https://dl.acm.org/doi/10.1002/spe.4380200104
paper_keyword: malloc
paper_year: Software - Practice & Experience, 1990
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents the design and implementation of a simple memory allocator that outperforms previous designs by
taking advantage of object lifetime.
The paper observes that object allocation can be as simple as incrementing a pointer on a stack allocator, while 
object deallocation, while usually non-trivial on such allocators, can be optimized by leveraging bulk object 
deallocation, which is not uncommon in many scenarios, and thus be amortized across objects with the 
same lifetime.
