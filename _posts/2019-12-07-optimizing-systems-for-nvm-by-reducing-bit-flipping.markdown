---
layout: paper-summary
title:  "Optimizing Systems for Byte-Addressable NVM by Reducing Bit Flipping"
date:   2019-12-07 16:35:00 -0500
categories: paper
paper_title: "Optimizing Systems for Byte-Addressable NVM by Reducing Bit Flipping"
paper_link: https://dl.acm.org/citation.cfm?id=3323301
paper_keyword: NVM; Bit Flip
paper_year: FAST 2019
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes an optimization to reduce bit flips on Byte-addressable Non-volatile memory (NVM). The paper begins by
pointing out that NVM is different from DRAM regarding write performance characteristics in a few aspects. First, NVM writes 
(we assume PCM) need to flip bits by heating the small crystal in the cell. This process consumes approximately 50x more 
power than DRAM write, and can be slower in terms of both throughput and latency. The second difference is that while 
DRAM write power consumption is proportional to the number of words written into the DRAM array, the power consumption of 
NVM writes is proportional to the number of bits that actually get flipped. It is therefore suggested by the paper that we 
should optimize for reducing the number of flipped bits on NVM when it is updated. In other words, the majority of power
consumed by DRAM is spent on cell refreshing, while the majority of power consumed by the NVM is spent on flipping bits.

This paper then identifies two benefits of reducing bit flips for NVM writes. The first obvious benefit is that we can 
reduce write latency and power consumption by not flipping certain bits if they are not changed by the write. The second,
less obvious benefit is that by combining this technique with wear-leveling techniques such as cache line rotation (i.e.
we rotate bits within a cache line for every few writes to make every bit in the line wear to approximately the same level), 
the wear can be ditributed more evenly on the device, which results in more programming cycles and higher device lifetime.

Previous proposals have been made to reduce the number of bit flips on the hardware level. The memory controller or cache
controller may determine whether to flip all bits before reading and writing a cache line depending on the number of bits
that need to be flipped. The paper points out, however, that wise decisions are hard to make without higher level information
about the workload. In addition, the hardware scheme needs to store metadata for encoding and decoding elsewhere, which 
complicates the design since now every cache line sized block in the address space is associated with metadata.

This paper proposes three data structure and one stack frame optimization targeting at reducing the number of bit flips
during normal execution. We present these optimization as follows. The data structure optimization leverages the observation
that on x86-64 platform, not all bits are flipped equally when updating a 64 bit pointer. To elaborate: The lower few bits
of the pointer is typically zero for alignment purposes, e.g. if the heap allocator always returns blocks aligned to 16 bytes,
the low 4 bits of the pointer will always be zero. Furthermore, the higher 16 bits of the virtual address always replicate 
bit 47 in the virtual address, which is required for usable canonical addresses. The allocator itself may also attempt
to maintain locality of memory blocks returned to the user. As a result, for two blocks of the same size returned from 
an allocator, it is very likely that the two blocks are close to each other in the virtual address space. If two such
pointers are XOR'ed together, it would be expected that only a few in the 64-bit result will be non-zero. 

The paper proposes doubly linked list using XOR'ed pointer, which we describe as follows. Instead of storing both the 
previous node and next node pointer in a single node, an XOR'ed linked list only stores the XOR'ed value of the two pointers.
This node layout has two advantages. First, by removing one pointer field from the node, we only update one 64 bit word
when the node is updated by insertion or deletion, resulting in less bit flipping. Second, as we have shown above, the XOR
value of two pointers to two same sized blocks will likely to have only a few non-zero bits. Updating this field, therefore, 
is expected to only flip a few bits. To obtain the next or the previous pointer of a node, we need to pass the address
of the previous or the next node to the traversal procedure, and recover the pointers by XOR'ing the stored value with
the address of the node. This is not a problem for linked list traversals, since the previous or the next node must have 
already been known during the traversal. For nodes at both ends of the linked list, instead of XOR'ing the pointer with 
NULL (whose value is zero), which does not change the actual value, the paper proposes to XOR the pointer with the address
of the node itself in order to reduce the number of non-zero flipped bits. This simple modification does not affect correctness,
since its pointer-based equivalence is just having a node pointing to itself at both ends.

The paper proposed a similar constructs
