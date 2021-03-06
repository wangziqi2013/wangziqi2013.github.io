---
layout: paper-summary
title:  "A Frequent-Value Based PRAM Memory Architecture"
date:   2020-12-03 17:08:00 -0500
categories: paper
paper_title: "A Frequent-Value Based PRAM Memory Architecture"
paper_link: https://ieeexplore.ieee.org/document/5722186/
paper_keyword: Compression; NVM; Frequent Value Compression
paper_year: ASP-DAC 2011
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Using frequent value compression for NVM device to reduce the number of bits a code word occupies, saving write 
   energy.

2. If a word is smaller than the size of the slot in which it is stored, the best way of wear leveling is to shift the
   word within the slot, such that writes will be distributed evenly regardless of the size of the compressed word.

3. Use dynamic training with a ranking algorithm: Each entry in the frequent value table under training process has a 
   counter, which is incremented by one when the value occurs. When the counter overflows, the entry is moved upward
   by one. When new entry is to be inserted, the bottommost entry is evicted.

4. Does not dynamically update the mapping table after it has been generated, based on the observation that these
   tables tend not to change too much during the execution.

**Questions**

1. This paper assumes that NVM is used as a cache for disk. I think a more proper expresion would be that the 
   NVM device is used as main memory and that disk is used as swap storage. 

2. The wear leveling technique only evenly distributes writes over all bits for a single word. It cannot reduce
   the different in wear between words at different locations on the same row. 

This paper proposes a compressed NVM architecture for better wear-leveling using frequent value compression.
The paper identifies one of the most important issue with NVM is that its lifetime is not infinite, which actually
has limited write-erase cycles. Without proper management, frequently written cells will wear out fast (in a matter
of days), rendering the entire device unusable.
Another minor issue is that NVM write energy is much larger than DRAM. Reducing the number of bits written into
the device, therefore, becomes critical for energy consumption.

The paper assumes the following architecture. NVM is deployed as a fast, byte-addressable cache between the cache
hierarchy and a backing store, such as hard disk. Cache lines can be brought into and written back from the NVM
device as they are accessed and evicted respectively. 
Compression is performed on a word-to-word basis, with the word size before and after compression being configurable 
parameters. The word size after compression also limites the size of NVM's internal code word mapping table, 
the size of which must not be larger than 2^K where K is the number of bits in compressed words. 
The mapping table is necessary for both compression and decompression, as we will see below.

This paper adopts frequent-value compression, which is commonly used in cache compression proposals, in NVM
architecture to preserve energy and protwct device, rather than saving storage. 
Each NVM row now has a different layout. Instead of being a non-structured, flat bit array, which
stores uncompressed words one next to another, the paper proposes that each row be divided into compressed words.
Each compressed word consists of a data region, and a bit indicating whether it stores a compressed word or not.
The data region takes the same number of bits as an uncompressed word.
If the bit is "1", then the data region stores an uncompressed word, and otherwise, it stores a compressed word 
(the exact bit offset where the word starts is non-trivial, as we will see later).
Each row also has one extra bit indicating whether it has been written into since brought into the NVM.
This bit is used to identify whether decompression is needed while it is accessed. The bit is cleared when a row
is populated with data just read from the backing store, and is set when a write back request with dirty
data is received from the LLC.
If the bit is clear, then a special data path will be activated to bypass the decompression circuit, which enables
faster reads of uncompressed data, and saves energy by clock-gating the uncompression circuit in this case.

Data is compressed when being inserted into the row. This happens when dirty data is written back from the LLC, and when
read from the disk. Data is decompressed when they are fetched by the LLC, and when they are written back to the disk, 
if dirty.
Compression works by replacing commonly occuring values with a translated code word, which uses less number of bits.
Decompression works by performing the reverse of compression, i.e., replacing compressed code words with their original
values. These two tasks utilize a hardware mapping table, which is implemented as a multi-ported SRAM and CAM, which 
stores uncompressed words identified as frequent values in different locations.
During compression, the CAM is used with the uncompressed word being the data to be searched, and the index returned 
is used as the compressed code word. During decompression, the SRAM is used with the compressed code word as index.
The content of the slot is retrieved and written to the input as the uncompressed word. 
If a word is uncompressed, i.e., the per-word bit is set to zero, then the decompression circuit is bypassed, and the
content of the data region is directly written to the output.
Similarly, if a word to be compressed is not found in the CAM, i.e., it is not a frequent value, then the word will
be written directly to the array, with the per-word bit set to zero.

To further improve the lifetime of the device, the paper also proposes that, for a compressed word, its storage location
is not static in the data region of the slot. When a slot is being written, the starting bit of the compressed word
will be the ending bit of the previous word. The compressed word will also wrap around to the beginning of the slot
when it reaches the end. This way, all writes are distributed evenly over bit cells in the slot, which is beneficial
for device lifetime. To this end, each slot also has two extra slots that track the starting bit offset. Size of the
compressed word need not be tracked, since it is statically determined as one of the compression parameters.

The paper also discusses the selection of compression parameters and the trade-offs. If the word size is too large,
then frequent values are more difficult to classify, since there are more possible patterns with longer words.
If, however, the word size is too small, the overhead would be larger, since this design adds one extra bit per word.
In addition, the compression and decompression circuit would also be more complicated, since more words per 
row are processed.

At the end, the paper discusses two possible ways of training the mapping table. The static table can be generated
by profiling the application with certain workloads. Although this will not work well for all applications and all
inputs, it is a good fit if the machine only executes with a small set of programs and inputs.
Dynamic table can also be generated at early stages of the execution, and then used during the restof it. 
Once the dynamic table completes training, it cannot be updated further, since otherwise code words in the NVM device 
should also be updated, which incurs extra writes, contradicting with the goal of reducing wearing and power 
consumption. In addition, it is also observed that frequently values rarely change during the execution.
The dynamic table is generated as follows. Initially, the SRAM array is initialized with invalid entries, except
that only one of them is zero (the CAM part is disabled for training). 
Each entry is associated with a counter that tracks the number of times the value in this entry occurs since last 
time it was inserted or promoted.
During the execution, for each value accessed by the processor, the value is inserted into the table, if it has 
not been there, or the associated counter is incremented by one. When the counter value overflows, the 
entry is swapped with the entry above it, if it is not yet the first entry, and the counter is reset.
If an entry is to be inserted, and the table is full, the bottommost entry is evicted, and a new value is inserted.
The training process completes after a pre-defined period of time, and the table becomes read-only, which is then
used by the NVM controller for compression and decompression.
