---
layout: paper-summary
title:  "Super-Scalar RAM-CPU Cache Compression"
date:   2020-09-23 23:49:00 -0500
categories: paper
paper_title: "Super-Scalar RAM-CPU Cache Compression"
paper_link: https://ieeexplore.ieee.org/document/1617427
paper_keyword: Compression; Database Compression
paper_year: ICDE 2006
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes a new database compression framework designed for new hardware platform. The paper identifies the 
importance of database compression as reducing I/O cost. There are, however, three drawbacks that prevent previous approaches
from fully taking advantage of the performance potential of hardware.
First, existing algorithms are not designed with the underlying hardware architecture and the newest hardware trend in
mind, resulting in sub-optimal execition on the processor. For example, the paper observes that modern (at the time of
writing) CPUs often execute instruction in a super-scalar manner, issuing several instructions to the same pipeline stage
at once, achieving an IPC higher than one.
Correspondingly, higher IPC on existing algorithms can be achieved, if the programmer and compiler can transform an 
algorithm to take advantage of data and control indepenent parallel instructions.
In addition, on pipelined microarchitecture, when data or control hazards occur, the pipeline has to be stalled until
the hazard is resolved, hurting performance. This implies that the algorithm should refrain from using branching structures,
while performing as many parallel loads as possible.
Second, conventional delta- or dictionary-based compression algorithms may not achieve optimal compression ratio in the
presense of outliers. Outliers can increase the number bits required to encode a tuple, but contribute to only a 
small fraction of total data storage. By not compressing outliers and always storing them in uncompressed form, 
the value range of compressed value can be greatly reduced, resulting in less bits per tuple and higher compression ratio.
Lastly, existing database compression schemes put the compression boundary between disk and memory page buffer, meaning 
that pages are stored in decompressed form once brought into the memory, enabling fast random access. 
This architecture has a few disadvantages. First, this causes significant write amplification, as the compressed page
is first read via I/O, and then decompressed in the memory. Second, this also damands higher storage since uncompressed
pages are larger than compressed pages.

The paper addresses the above challenges with the following techniques. First, the algorithm proposed in this paper
mainly consists of small loops without branching. Compilers may easily recognize the pattern, and expand the loop
using loop expansion or loop pipelining. The former technique simply expands several iterations of the loop into the 
loop body, while the latter further re-arranges operations from different iterations to overlap the execution of 
multiple iterations to increase the number of parallel operations. For example, if a single iteration consists of a few
loads, some computation, and then stores, these loads and stores can be "pipelined", i.e., the load operations of the next
few iterations can be promoted to be executed together with the loads in the current iteration, if the memory
architecture can sustain the read bandwidth.
In addition, by transforming "if" statements into other structures, such as predication, or multiple loops, unpredicable 
control hazards are eliminated.
Second, the paper proposes a unified format supporting both delta- and dictionary- based compression with exceptions. 
Common values or values in the short range are compressed using dictionary or delta. Outliers that occur infrequently
are encoded in uncompressed form, and stored separately. As a result, fewer bits are required to encode common or small 
deltas, reducing the compressed size.
Lastly, the paper proposes a compressing format that allows fast random access within a compressed page. The page buffer,
therefore, can store only compressed pages, which are decompressed only at query time, saving both memory bandwidth and 
space.

Overall, the paper assumes that the compression algorithm is applied to database columns, which are stored in pages
ranges on the disk. Compression is performed in the unit of chunks, which consists of several disk pages for maximizing
disk I/O throughput. Chunks can be compressed and decompressed independently, which is organized as follows. Each chunk
begins with a chunk header, which stores compression metadata, such as compression type, dictionary, base value, and 
various pointers to the rest parts. The second part is called an "entry point section", which stores an array of pointers
to exception values. Note that for storage efficiency, not all exception values are tracked in this array. In fact, only
at most one exception out of 128 compressed words is tracked, enabling fast random access as we will see below. 
The third section is just an plain array of compressed words, which can be both encoded words, or exception slots.
Encoded words can be decoded by consulting the dictionary, or adding them onto the base value. Exception slots, however,
form a linked list of slot positions, i.e., an exception slot stores the index of the next exception slot in the array.
Exception values are not stored in-line since they use more bits per value than the encoded wors.
The pointer to the first and middle exception slots are maintained in the entry pointer section, as stated earlier.
The last section stores exception values, which are uncompressed words. The last section grows backwards from high
address to low address, and each value in this section corresponds to one exception slot in the previous section.
In other words, exception values are always stored continuously and in the same order as they appear in the 
compressed section.

The decompression algorithm consists of two loops. In the first loop, it simply iterates over every code word in the 
compressed section, and adds the value stored there with the base value in the header. This process does not distinguish
between normal code words and exception values, and therefore contains no branch. No control and data hazard is incurred
in this process. As a result, exceptions will be mistakenly decoded as a meaningless value as exception code words store 
the index offset from the current position to the next exception position. 
The next step is to "patch" exception values by iterating over the exception list starting at the header, and then copy
the exception value to the corresponding index in the decoded array. The iteration begins by reading the first index
position of the exception stored in the header, and then copies the last element of the exception array (recall that it 
grows downwards) to the index. Each iteration just adds the current index value and the value stored in the current index
of the encoded array, and decrement the exception array pointer. This process also incurs no control hazard due to lack
of branch, but it may introduce data hazards because of the delta-compressed linked list structure. The paper argues, however,
that since there are only a few exceptions expected, the number of elements in the list is supposed to be small,
and hence data hazards will not significantly affect performance.

Random accesses on the compressed array does not require decoding the entire array. Instead, the access can just read the
code word at the given offset, and then add it with the chunk's base value. To deal with exceptions, the operation also
leverages the entry point section at the beginning of the header. The entry point section is searched linearly for the 
maximum exception index smaller than or equal to the requested index. Then the operation follows the delta-compressed 
linked list, until an element whose index is larger than or equal to the requested index is reached. 

