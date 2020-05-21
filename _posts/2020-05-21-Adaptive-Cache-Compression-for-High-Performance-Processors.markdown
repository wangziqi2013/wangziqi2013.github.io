---
layout: paper-summary
title:  "Adaptive Cache Compression for High-Performance Processors"
date:   2020-05-20 04:20:00 -0500
categories: paper
paper_title: "Adaptive Cache Compression for High-Performance Processors"
paper_link: https://dl.acm.org/doi/10.1145/1028176.1006719
paper_keyword: Cache Compression
paper_year: ISCA 2004
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes an adaptive scheme for performing cache compression using a combination of LRU and predictors.
Cache compression serves the purpose of increasing the effective cache size, allowing more data to be cached at the 
certain level, which increases the chance that a request will hit the cache.
The paper, however, points out that cache compression is in fact a trade-off between hit latencies and hit rates.
By performing in-cache compression on write back and decompression on line fetch, more cycles are dedicated to
hardware compression and decompression, which is on the critical path. Such costs are hard to eliminate due to the 
way a cache is accessed. On the other hand, since more cache lines can be stored on a level, chances are that lines
which should have been already been evicted get hit, where in a non-compressed cache these accesses would incur misses.

This paper assumes a two-level, exclusive cache hierarchy (pressumably on a single core). The L1 cache is entirely
not compressed, since L1 latency is one of the most critical factors for instruction throughput. The 4-way set associative 
L2 runs in compression mode, which can be turned off if the system determines that no benefit is gained from compression.
The L2 cache uses LRU as replacement algorithm. The LRU stack is necessary for the algorithm to identify accesses
that gain benefit or do not gain benefit from compression. The paper also suggests that any replacement algorithm would 
work, as long as an ordered stack is maintained for a set (or more precisely, for the last few ways enabled by compression).
The paper also proposes adding a small victim cache as a buffer between L1 eviction path and L2, to absorb longer L2
write latency.

The L2 cache is organized as follows. Different from traditional set-associative caches where each tag is statically bound
to a data slot of 64 bytes, the L2 cache proposed by this paper does not bind tags and data slots statically. Instead,
8 tags are provisioned for each set, implying that the effective set size can be doubled in the best case. Data slots
are divided into 32 8-byte segments, which can hold 4 uncompressed cache lines, but if some or all of them are compressed,
up to 8 lines can be stored with any set in the best case. 

Tags are bound to data segments dynamically at run-time. Each cache tag contains two fields describing data: base and 
size. The base field points to one of the 32 segments as the starting segment of line data. The size field indicates the 
number of segments the line needs to take. Partial segments are always rounded up, and the compression algorithm is 
responsible to distinguish useful data from garbage from the last partially filled block. The tag also stores regular 
information, such as coherence states and address tag. One notable difference between the proposed design and a regular
cache is that the base and size field are never invalidated, unless the coherence state is "I". When a cache line is 
invalidated by an L1 request (to maintain exclusiveness) or evicted from the L2 cache, we still keep the mapping valid,
and set the state to NP, meaning valid data is not present, but the mapping is still present. When a block is acquired 
by coherence, it is set to "I", in which case segments used by the tag is unmapped.
Note that LRU requires "I" lines and "NP" lines be moved to the end of the LRU stack, since LRU always prioritizes 
using space that do not contain valid data to evicting valid data.

The L2 cache maintains an invariant that data layout in the segment must be consistent with tag layout, i.e. data segments 
of tag i must be stored in smaller segments before tag j, as long as i < j. In order to read the data of tag j, the 
cache controller takes the size field of all tag i (i < j), and computes the sum as the beginning segment of tag j's 
data. This can be done efficiently using a multi-way parallel prefix adder. 

The paper assumes Frequent Pattern Compression (FPC) without giving any detail of the algorithm. The algorithm can 
be implemented on hardware with very little extra hardware and reasonable run-time latency, which makes it ideal
for L2 cache compression. When a read access is received by L2 cache, address tags are checked as usual. If a hit 
is signaled, the segment offset of the tag is computed as described above, and segments are read until all of them are 
delivered. These segments are decompressed before senting to L1.

When a cache line is evicted or fetched by L1, the L2 controller does not immediately invalidiate the tag. Instead, both
line base, size and the address tag are preserved the address tag, and the state is set to NP. 

When the line is written back by L1 or fetched again, the controller first checks whether the selected tag state is NP. 
If true, it checks whether the size is sufficient for holding the block. If also true, then the block is written into the 
segments without rearranging the layout. If, however, the block size exceeds segments available for the tag, then the data
segments as well as tags need to be compacted to make space for the new block, and also eliminate any external fragmentation
that prevents any new blocks from being installed (e.g. moving "NP" and "I" tags to the end of the tag array).

The paper did not explain how "I" state works, and neither can I figure out without wild guessing. Given the fact
that the size field must always be kept valid for lookup, and the paper suggests that segment compaction is done lazily, 
I cannot see how using "I" state benefits the overall efficiency. 
Maybe it is just used to initialize the cache at boot time, allowing size 0 be used when the tag is actually unbounded 
to data segments.

A predictor is also featured in the design to turn off compression when the cost of increased latency outweigh the benefit
of increased hit rate. The paper classifies hits into three classes using the position of the line in LRU stack. If the
line being hit is below 4 (i.e. closer to the LRU end of the stack; same below), then the hit would have not been possible
without compression. In this case the scheme brings N cycles of benefit where N is L2 penalty. If the line is above LRU
stack position 4 (inclusive), and the line is not compressed, then it would have been a hit even if compression is 
turned off, and the benefit is zero. If, however, that the hit line is above position 4, but is compressed, then 
compression does not introduce extra benefits, but we have to pay for the extra decompression cycles, which can be 
quantitized by adding a benefit of -M where M is the latency of decompression.

L2 misses are also classicied into different categories based on whether compression can bring any benefit. If the cache 
miss hits a line in NP state (which is classicied as a miss, but since we preserved the address tag, it can still show
what position the line is in the LRU stack), we sum up compressed sizes (not actual size, as in cache access) of all 
previous tags in the LRU stack, and compare that with the number of segments per set. If the sum is smaller than the 
number, meaning there is sill space if the line were not evicted or fetched, but since some of the lines may not 
be stored compressed, the block was evicted somewhere earlier during execution (I think the author ignored L1 fetch here).
In this case, the miss is considered as avoidable, since it is some uncompressed lines that prevent the current line 
from being cached. If, on the other hand, the sum of all previous compressed sizes exceed the segment count, the 
miss is unavoidable.

