---
layout: paper-summary
title:  "Compresso: Pragmatic Main Memory Compression"
date:   2020-07-13 19:10:00 -0500
categories: paper
paper_title: "Compresso: Pragmatic Main Memory Compression"
paper_link: https://ieeexplore.ieee.org/document/8574568
paper_keyword: Compression; Memory Compression; Compresso
paper_year: MICRO 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Metadata mapping can be performed by direct mapping into a reserved address space of physical DRAM. The overall overhead
   is as low as 1/16 of the address space (assuming 64B to 4KB mapping).

2. The "caching only lower half" strategy of metadata entry is a novel idea never seen anywhere before.
   
3. Identifying cold pages by cache eviction
  
4. By making each metadata entry 64 bytes, all metadata reads can be done with one DRAM access.

**Questions**

1. Although the paper delivers its ideas without any missing parts, it can be more structured and organized. For example, 
   there is no mentioning of the metadata cache until Sec. IV.B.2, and neither after.
   Rather than proposing and describing a research prototype, this paper is closer to evluating different ideas of 
   main memory compression, realizing the trade-offs, making the correct design decisions, and finally assembling
   all aspects together into a working memory compression scheme.

2. It is not the size of the metadata cache must be larger than last level TLB, but the range of OSPA covered.
   TLB entries are much smaller than metadata entries. Less storage is required for TLB than metadata cache if the 
   same number of pages are to be covered.
   Also with huge pages this is just impossible.

This paper proposes Compresso, a main memory framework featuring low data movement cost, low metadata cost and ease of 
deployment. The paper begins by identifying two issues with previous memory compression schemes. The first issue is 
excessive data movement, which is not only a major source of negative performance impact in many cases, but also often ignored 
due to careless evaluation. Data movement is needed in several occasions. When a compressed cache line is written 
back, if the compressed size is larger than the physical slot allocated for storing the old compressed line, then 
the rest lines after the dirty line has to be shifted towards the end of the page to make more space. In addition, if
the sum of compressed line sizes exceed the total page capacity, a larger page should be allocated, and all compressed
lines in the old page should be copied over to the new page.
The second issue is OS adoption. The compressed main memory scheme may be abstracted away from the OS, which leaves
the OS unmodified when deploying the scheme, suggesting easier adoption. It is, however, also possible that the OS 
is aware of the underlying compression, and will accommodate by allocating different sized pages, manipulating extra mapping 
information for compressed pages, and reallocating pages on hardware request. The paper argues that a transparent compression
scheme is better, since it encourages adoption and minimizes OS migration cost.

The paper then identifies four important design choices and trade-offs it makes. The first is the compression algorithm.
The paper selects Bit-Plane Compression (BPC) as the cache line compression algorithm, due to its simplicity and higher
compression ratio. BPC combines BDI, FPC and RLE by first transforming the input symbols with BDI-style delta, bit-plane 
rotation, and bit-wise XOR to generate as many zeros as possible, and then compressing the resulting stream with low 
entropy with either FPC or RLE. The paper slightly modifies BPC such that the transformation is not always applied. The
compressor always compares BPC with directly applying FPC + RLE without the transformation to further avoid pessimistic
cases with BPC. Compression is performed on 64 byte cache line boundaries to prevent over-fetching when multiple lines
are compressed together.

The second design choice is address translation boundaries. In a compression-aware OS, address translation and page allocation
should both accommodate variably sized pages and non-linear block mapping within a page resulting from memory compression. 
The OS page allocator directly allocate from compressed address space (called "MPA") which is directly mapped into hardware.
The allocator should keep several size classes for pages with different compressibility. When a compressed page changes 
size, the OS should also be notified of such event, and explicitly allocate a new page in larger size classes.
The MMU, in the meantime, maps linear addresses within a page to actual block addresses in MPA, after computing the 
block offset using extra compression metadata. In this mode, hardware and software cooperate to maintain the compressed
address space, communicating with each other via compression metadata and asynchronous exceptions.
This paper, however, argues that compression-aware OS may prohibit the adoption of compression, since it not only
requires significant changes to the OS page management policy, but also raises compatibility concerns for external
devices (e.g. DMA) that also need to access memory via bus transactions. In this case, the DMA device will not be 
able to direct access memory without significant hardware change, since the bus transaction now uses addresses from the
compressed address space, which is no longer linear, and must be computed using compression metadata.
Based on these reasons The paper proposes adding an intermediate address space, called "OSPA", between the VA and MPA.
OSPA has the same mapping as uncompressed address space, in which all pages are of uniform size, and all blocks are linearly
mapped within the page. The MMU generates bus transactions using OSPA addresses, which enables DMA and other bus 
devices to access memory in the old fashion. The memory controller will perform the next stage translation from OSPA
to MPA. This design isolations memory compression from higher level components of the memory hierarchy, which features
fast and seamless adoption.

The third and fourth design choice is the packing of cache lines within a page, and the packing of pages in the MPA. 
In terms of cache line packing, the two extremes of aligning them to a pre-determined size boundary, as in LCP, and 
packing them compactly, will not work well. The former reduces the efficiency of compression, since the compressibility
of a page is irrelevant to the compressibility of cache lines in the page. The latter introduces unnecessary data movement,
since any size increase of a dirty cache being written back will cause the page to be shifted. 
The paper therefore proposes that cache lines be classified into a few size classes. Individual lines are aligned to the 
size class boundary of the previous line, if any. This way, the compressibility of a page is still relevant to the
compressibility of cache lines, while slight size increases will not cause any data movement, as long as the cache line
still fits in that size class.
Regarding page packing, the paper also points out that variable sized chunks will not work, since it complicates
memory management for finding blocks of appropriate sizes, and may decrease compression efficiency by introducing internal
and external fragmentation. The paper favors incremental allocation, in which memory blocks are given to pages
incrementally in the unit of 512 byte chunks. Note that this is different from having multiple size classes for pages,
in which data movement is necessary to copy old page data to the new page when the old page overflows.
In incremental allocation scheme, the metadata for an OSPA page contains several pointers for each of the 512 byte chunks.
Data only needs to be copied incrementally as the name suggests.

We next describe the operation of Compresso. Compresso does not change OS's page allocation, address mapping, and MMU's
VA to OSPA address generation. When an OSPA address appears on the system bus, the memory controller performs OSPA to MPA
address translation by consulting a metadata area at the beginning of the MPA. 
The translated address is then used to access physical DRAM to fetch the compressed cache line. Note that since the 
paper assumes a conventional DRAM interface, the granularity of DRAM access is still 64 bytes, in which case two 
DRAM transactions might be needed in order to fetch a boundary crossing line. To reduce cross-boundary cache lines,
the paper suggests that the size classes be chosen such that most lines are properly aligned to DRAM access boundaries
(the paper uses 0, 8, 32 and 64).
The compressed line is decompressed before sending to the upper level.

In the case of dirty write backs, the compression engine first compresses the line, and compares it with the size class.
If the compressed line can still fit into the slot, the line is just written into the slot. Otherwise, the line overflows
to the end of the page, called an "inflation room". The matadata word has a few bytes dedicated for addressing overflowed
lines, as we will see below. If the inflation room runs out, but there are still free pointer slots in the metadata, the 
memory controller will incrementally allocate another 512 byte chunk, if the page is not already 4KB, in order to extend
the inflation room. If no more inflation pointers can be used for overflow lines, and/or the page is already 4KB, the 
memory controller will recompact the page. A new 512 byte chunk is also allocated if the page is not already 4KB.

We next discuss Compresso's metadata management. Compresso reserves a metadata region at the beginning of the MPA at
system initialization time. One 64 byte metadata entry is reserved for each 4KB OSPA mapping. The initialization routine 
also reports more memory (e.g. twice the physical memory size, assuming an overall 2:1 compression ratio) than actual 
MPA to the OS. On receiving a bus transaction containing a block address, the memory controller first extracts the page
frame number from the address, and then finds the metadata entry with exactly one aligned DRAM read. The memory controller
then use the line offset from the address to locate the physical address of the compressed line, after which DRAM
is accessed. 
The metadata entry consists of four regions. The first region is a 2 byte control word, which contains valid bit, 
zero bit (whether the page is all-zero), compressed bit (whether the page is compressed at all), and the free space
that remains at the end of the page. The second region is 8 chunk pointers of 4 byte each. Chunks are incrementally
allocated to a page by pushing them to the tail of the pointer array. The third region is an array of 2 bit size class
indicates for describing the size of compressed lines, which amounts to 16 bytes. The last region is an index array for
overflow lines that are stored in the inflation room. 17 slots are provided for overflow lines. Each element of the 
index array is a 6 bit field storing the ID of the overflow line in the corresponding location of the inflation room.
Note that cache lines stored in the inflation room are still classified into one of the four size classes, which is 
stored in the third region. Cache lines, however, can be of different size classes while in the inflation room to
maximize space efficiency.

The paper also proposes a metadata cache on the memory controller to accelerate access to recently used lines. No
detailed description of the metadata cache is given, but a conventional set-associative cache will suffice. The paper
suggests that the range of OSPA covered by the metadata cache should not be smaller than the last-level unified TLB of 
the system, such that the normal access path without last-level TLB miss should also be unaffected by metadata cache 
misses.
To further improve metadata cache hit rate, the paper also suggests that for uncompressed pages, it is sufficient to
only cache the first half of the metadata entry, since only status bits and chunk pointers are needed to perform linear
translation within uncompressed pages. 
The second half of the physical slot can then be used for caching another uncompressed page's translation.
Although this also requires over-provisioning the number of tags in the metadata cache, the extra storage for tags
is insignificant compared with metadata entry size.

The paper proposes two extra optimizations for improving the efficiency of Compresso. The first is page overflow prediction,
which directly expands a page to 4KB without having to go through the middle stages. The reasoning behind is that pages
might be initialized with zero by the library before they are written by the application. In this case, the page will
always begin its life cycle with the minimum possible configuration. In later stages of execution, as the application
writes into the page, the page needs to be expended a few times before it reaches 4KB, if the page is hardly compressible,
causing unnecessary bandwidth if this could be predicted. Compresso uses one global predictor, which is a two bit saturating
counter incremented for every global page overflow, and an array of local predictors, which are saturating counters
incremented for every cache line access for the page (page numbers are hashed onto the counters). On the next cache line
overflow, if both the global and the local counter are saturated, the page will be directly expanded to 4KB, with all lines
stored uncompressed. No more unnecessary traffic will be generated by this page at the cost of lower compression ratio.

The second optimization is background page recompaction, which is triggered when a metadata entry is evicted from the cache.
Eviction is an indication that the page has not been accessed for a while, turining cold gradually, which qualifies 
for recompaction as it frees extra chunks by rearranging existing lines. The memory controller computes the sum of 
compressed block sizes in the page, and compares that with the current storage allocated to it. If the difference is larger
than 5112 bytes, implying that at least one chunk can be freed, recompaction will be triggered, which reads out all lines
in the page to a temporary buffer, and streams them back in-order for both fast access and storage saving.
