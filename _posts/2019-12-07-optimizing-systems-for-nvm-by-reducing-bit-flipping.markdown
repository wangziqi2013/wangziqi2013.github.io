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