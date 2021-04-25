---
layout: paper-summary
title:  "The Cache for Compressed Caching in Virtual Memory Systems"
date:   2020-07-24 22:03:00 -0500
categories: paper
paper_title: "The Cache for Compressed Caching in Virtual Memory Systems"
paper_link: https://www.usenix.org/legacy/publications/library/proceedings/usenix01/cfp/wilson/wilson_html/acc.html
paper_keyword: Compression; Memory Compression; WK Compression
paper_year: USENIX ATC 1999
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Using a directory to capture the 16 most recent words and to recognize patterns in this short window. This is better
   than only keeping the previous "base" value as in some compression algorithms.
   This is also better than performing extensive searches for possible base values.

**Questions**

1. The WK compression algorithm may result in larger compressed size than uncompressed size. This pessimistic case
   could happen if most of the tokens cannot find matches in the dictionary. 
   The paper should mention that such pages are not stored in compressed form, and also should not be cached in
   the in-memory page cache.

2. To be honest I did not quite follow the adaptive compression part. It might be just because this paper is from
   a while ago, at which time the technical terminologies and system assumptions are different.

This paper proposes compressed page cache for virtual memory systems. The paper appreciates the benefit of page compression
for keeping more active pages in the main memory and thus reducing page fault costs, as oppose to previous works where
page compression has been proved to be not useful unless the machine is equipped with slow or no disks. 

The paper makes two contributions. First, it describes a fast and efficient dictionary-based compression algorithm for
compression data on page granularity, which is tuned to fit into common scenarios of page data layout rather than text.
The second contribution is an adaptive compression scheme that dynamically adjusts the compression ratio based on runtime
behavior of the program. The paper observes that when the working set can be fully included in the main memory, further
increasing the compression ratio is detrimental to performance, since the processor wastes unnecessary cycles on compression
and decompression of pages evicted from the main memory. On the other hand, when the system observes excessive page
faults and high costs paging costs, an increase in the overall compression ratio could help reducing the frequency of 
page faults at the cost of more cycles dedicated to compression and decompression. Since each application may demonstrate
different behavior at runtime, or even at different stages of execution, the balance must be found online and be able to
self-adjust to adapt to program behavior changes.

This paper assumes a page cache architecture. When a page is selected by LRU or other replacement algorithms, instead
of writing these pages back to the disk, if they are dirty, the OS compresses the page, and stores them in a special area
of the main memory, called the "page cache". When a page fault occurs, the page cache is first searched for the virtual
page number that triggered the fault. If a match is found, then the compressed page in the page cache is decompressed
and served to the VMM as if it were read from the disk.
Although the paper assumes LRU as the replacement algorithm, any algorithm is feasible as long as it ranks pages in the 
main memory and selects the lowest score candidate as victim.

The paper proposes a dictionary-based compression algorithm tuned for common page layouts. The paper identifies potential
problems with classical compression algorithm such as LZ as incorrectly assuming in-memory data structires and arrays
would tend to contain literal repetitions of previously seen tokens in the near future, which is usually the case with
human readable text since only a subset of characters and words would occur within a small window of the text.
The paper argues that two types of data, integers and pointers, dominate the token that the compression algorithm has to
process. Both types demonstrate abundant degrees of redundancy on their higher bits, which hardly changes when a few of them
are laid out in the address space. For integers, the source of redundancy is that their distribution is most likely not
random over the value domain. In practice, applications tend to contain small integers, and/or integers that only use
a small fraction of bits. This is because: (1) Human beings are accustomized to counting from zero, and hence are more 
likely to use smaller integers to represent loop indices, offsets, real-world data points, etc. For these small integers,
the higher bits are either all-zeros or all-ones depending on the sign; (2) Even larger integers may expose certain locality,
especially if they are real-world data pointers, since physical objects are continuous and will hardly exhibit abrupt changes.
In this case, the higher bits of the integers are not zero, but they may remain constant.
(3) Pointer values are often clustered, in a sense that similar sized objects tend to be placed close to each other by 
the allocator. This is a result of both size-class list based allocation, and locality optimizations for cache performance. 
For these pointers, their higher bits typically remain the same, which poses another perfect opportunity for compression.

Based on the above observation, the paper proposes the WK compression algorithm, with the "WK" coming from initials of
the first and second authors of this paper. The WK algorithm reads the input stream in the granularity of 32-bit tokens.
The algorithm maintains a dictionary of recently seen tokens, which is compared with incoming tokens for full or partial 
matches. Two types of matches are supported: A full match, which occurs when all 32 bits are identical to one of the 
dictionary entries; A partial match, which refers to the case where only higher 22 bits match. 
Each token is encoded into a 2-bit type field, followed by one or two extra fields for restoring the original word. 
If the type field is "00", the token is a full match, and the next field will be the index in the dictionary.
If the type field is "01", the token is a partial match, and the next two fields will be the index and the remaining
10 lower bits of the original token. 
If the type field is "10", the token is zero, and there is no extra field. Optimizing for zero can help further 
improving the compression ratio, since zero is one of the most frequently occurring values in almost all workloads,
which is also widely used for initialization, padding, indicating invalid values, and so on.
If the type field is "11", the token is uncompressed, and the next 32 bits are the uncompressed token.
The paper suggests that the dictionary can be implemented either as a direct-mapped array of 16 entries, or as 4 * 4 
set-associative software cache running LRU as replacement algorithm.
The dictionary is updated when a no-match is detected, which evicts an existing entry if a conflict occurs.
The paper also suggests that in order to maximize compression and decompression throughput, different fields are written
into separate buffers, which are then stored in consecutive chunks within the compressed page.

The paper then proposes a mechanism for dynamically adjusting the compression policy for evicted pages. As discussed
in previous sections, always compressing evicted pages is not a good choice, since it wastes cycles if the page
will not be frequently accessed in the near future.
The paper proposes that compression be turned off when the cost of compression exceeds the benefit of reduced disk accesses,
and turned back on when the opposite happens. 
The proposed mechanism maintains LRU information for all pages in the system, rather than only pages in the memory.
The algorithm sets several pre-determined "effective memory size" goals, and maintain instances of LRU dry runs for these
goals. For example, given a machine with 100MB physical memory, two goals can be set: 1.5:1 and 2:1 compression ratio.
In the first case, LRU is maintained for 150MB of virtual pages, even after some of them are evicted back to the disk.
In the second case, LRU is maintained for 200MB of virtual pages.
The algorithm then evaluates the online cost of performing compression in order to achieve these goals. If a page that
is currently swapped out but stored compressed in the main memory cache is hit by an access, the benefit of compression
under that goal is incremented by the cost of a disk access minus the cost of compression (most likely cycles).
On the other hand, if a page that is never accessed again in the page cache before it is evicted back to the disk under
some goals, the benefit of compression would be decremented by the cost of compression and decompression, since 
disk accesses is not avoided, but the system pays the extra cost of storing the page in the page cache.
At the end of the training phase, the OS selects the best-performing compression goal, and compresses every evicted 
pages until the compression goal is reached.