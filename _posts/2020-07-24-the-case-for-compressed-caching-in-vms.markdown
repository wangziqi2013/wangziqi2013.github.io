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


