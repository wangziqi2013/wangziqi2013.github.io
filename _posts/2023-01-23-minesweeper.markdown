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

**Highlight:**

1. Use-after-free bugs can be utilized by malicious attackers to inject the attack vector into a memory block
being used by the application after the block is freed.

2. We can borrow from GC mark-and-sweep algorithms to detect whether there are live references to a block
being sent to free(). If true, the block should not be deallocated. 
The scan process, however, does not need to be precise as in GC. 
As a result, both false positive and false negatives can occur.

**Comments:**

1. Does MineSweeper need to save allocation size somewhere as well (C++ can do this already)? What if a live reference 
points to the middle of an object after the object is passed to free()?

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
To achieve the design goal, MineSweeper integrates with the memory allocator's free function. When an object is about to
be freed by the application, instead of deallocating the storage and insert it into the free list, MineSweeper moves 
the object pointer into a quarantine list, hence preventing the object from being reallocated on another request. 
Periodically, MineSweeper scans the address space of the application, treating every aligned 8-byte value as a 
pointer, and deallocates those in the quarantine list whose has not occurred during the scan.
Note that this approach will incur both false positives and false negatives. False positives is a result of 
treating every value as a pointer. It might therefore be possible that some patterns or integer values coincide with 
pointer values in the quarantine list. On the other hand, false negatives can arise if actual pointer values 
are not stored on aligned boundaries, or that the pointer values are tagged (e.g., on higher bits with ARM's 
Pointer Authentication Code ISA extension). However, the paper argues that the two cases are relatively rare and 
can be addresses by application programmers (applications are assumed to be non-malicious).

We next describe the implementation level details. MineSweeper uses a bitmap to represent whether a pointer to a 
particular word exists in the application's memory. To this end, MineSweeper reserves 1 bit for every 128 bit (16 bytes)
of physical memory in the application's address space, incurring less than 1% of memory overhead. 
During the scan, MineSweeper treats every 8-byte aligned value as a pointer, and sets the corresponding bit in the 
bitmap by shifting the value right and using the result as an index into the bitmap.
Then, for every pointer in the quarantine list, MineSweeper tests whether the bit that corresponds to the pointer is
set. If true, the pointer is not deallocated as there can be potentially a live reference to the object. Otherwise,
the pointer value is freed.

The scan is triggered by the application thread when the amount of memory in the quarantine list exceeds a certain
threshold (15% of total heap size as suggested by the paper). The scanning process can proceed with the application
in parallel and access an inconsistent process address space. The paper noted that although this approach may miss 
some live references if the reference is copied around in the memory during the scan, the possibility of it 
actually happening is still low and will unlikely to be a major problem.

The paper also proposes a few optimizations. First, to prevent cyclic reference, i.e., two or more blocks in the 
quarantine list contain pointers to each other hence forming a cycle, which causes these blocks to be never freed,
MineSweepers fills a block with zero when free() is called on the block. Second, to avoid holding too much memory
resources in quarantine, large allocations that are satisfied by mmap() system calls, when freed, will be eagerly 
released to the OS kernel by calling madvise(). The block itself still needs to be inserted into the quarantine list
because the virtual address may still be reused by the OS kernel if not so.
In addition, MineSweepers should keep track of pages whose virtual addresses are still in-use while the physical
pages are deallocated. These pages will not be scanned as accessing them would cause the OS to page them back.
Lastly, the paper proposes to use multiple worker threads (six threads as suggested in the paper) to perform 
the scan. These worker threads are waken up by the main scan thread dividing the address ranges to scan, and each 
of them maintains their own bitmaps. The final result, on completion, is processed by the main scan thread to
produce the final scan result.
