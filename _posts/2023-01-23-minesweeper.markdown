---
layout: paper-summary
title:  "MineSweeper: A Clean Sweep for Drop-In Use-after-Free Prevention"
date:   2023-01-23 06:21:00 -0500
categories: paper
paper_title: "MineSweeper: A Clean Sweep for Drop-In Use-after-Free Prevention"
paper_link: https://dl.acm.org/doi/10.1145/3503222.3507712
paper_keyword: malloc; security
paper_year: ASPLOS 2022
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents MineSweeper, a memory safety tool that detects use-after-free cases for malloc library with little
overhead on both execution cycles and memory. MineSweeper is motivated by Mark-and-Sweep Garbage Collection (GC)
techniques that detect live references to objects. MineSweeper leverages a similar algorithm to detect potential
use-after-free cases by scanning for pointers that have freed by the application in the application's address space.
Compared with prior works, MineSweeper offers strong protection guarantees while only incurring marginal penalty
on execution time and memory consumption. Besides, MineSweeper does not require modification to the application
and only requires non-functional changes to the allocator.

The MineSweeper design addresses use-after-free scenario where a pointer from the malloc library is used by the 
application after free has been called to deallocate the pointer. In this scenario, a malicious attacker can 
request allocation of the same size as the deallocated block after which it populates the block with the attack vector.
If the targeted application later on uses the block to perform vulnerable operations, e.g., virtual function calls,
the attacker can hijack the control flow by populating the block with a function pointer to an attack routine.
As a result, the application is compromised and sensitive data might be leaked to the attacker. 

To address this problem, MineSweeper proposes that the actual deallocation of blocks that are freed via the free 
library call should be postponed until no other reference is held by the application. After this condition is met,
the application can never gain access to the freed block via direct pointer accesses (but is still vulnerable
to other forms of pointer anomalies such as buffer overflow) and hence the use-after-free scenario becomes impossible.

