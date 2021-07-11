---
layout: paper-summary
title:  "Extending The Lifetime of NVMs with Compression"
date:   2021-07-10 15:57:00 -0500
categories: paper
paper_title: "Extending The Lifetime of NVMs with Compression"
paper_link: https://ieeexplore.ieee.org/document/8342271
paper_keyword: NVM; FPC; Compression
paper_year: DATE 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. FNW and FlipMin can be applied on a per-block basis, i.e., not all blocks need to be encoded in order for it to
   work. Based on this observation, we can selectively turn off encoding for certain blocks if their compression
   ratio is low.

2. More than one encoding scheme can be applied. The trade-off here is between the metadata overhead and effectiveness
   of the encoding scheme. 
   In this paper, the compression ratio is used as the only factor for determining which scheme to use.

This paper proposes a technique for reducing storage overhead of applying data encoding to reduce bit flips of 
NVM writes. 
As NVM devices have limited write-erase cycles, and are generally more power-hungry for writes, previous works have 
focused on reducing the number of bit flips per write by encoding the data block to be written.
These schemes, however, generally require metadata tags for each block on the NVM, incurring storage overhead.
For example, Flip-N-Write (FNW) performs the best when every two bits of data is accompanied by one bit of metadata bit
to indicate whether the two-bit unit is flipped, causing a 50% storage overhead.
In FlipMin, the storage overhead can even be as high as 100%, meaning that the amount of storage doubles for storing 
the same amount of logical bits. FlipMin re-encodes words in the input block to longer words, such that each raw 
word has several different representations. The appropriate representation is then chosen to minimize the number of
bit flips on the location to be written. 

This paper uses compression to aid bit-flip reduction based on the following observations. 
First, data compression is effective in reducing the number of bytes a block needs to be stored. Conventional 
compression techniques aim to increase the logical capacity of the storage by over-provisioning tags and remapping 
blocks. Here, instead, we seek to reduce the metadata overhead of bit-flip reduction schemes, and as a result, 
blocks are still stored on their home locations without being remapped.
The second observation is that compressibility often varies for different parts of data. The number of bits saved
for the block can be employed to determine which bit-flip reduction scheme to use. For example, if the compression
ratio is above 2, meaning that the block is compressed to less than half of its original size, the FlipMin method
can be used. If the compression ratio is between 1.5 and 2, we can still use FNW. In all other cases, the block is 
simply stored uncompressed.

We next describe the operational details. When a block is to be written back to the NVM from the LLC, the controller
first attempts to compress the block using the 64-bit FPC algorithm (for less header metadata). 
The paper proposes that the three-bit headers for each compressed words are stored consecutively as a 
separate section before the payload, such that the offsets of the payloads can be determined in one cycle, and 
decompressed in the next cycle.
The total size of the header is 24 bits, since there are only 8 64-bit words per cache block.
Another feature of this arrangement is that the compressed size can also be computed easily without decompressing 
the block first, as the three-bit headers can always be found at known locations.
Then the compressed size is used to determine the encoding scheme in the next step.
As discussed above, if the compressed size is less than half of the original size, FlipMin will be used for optimal
results. Otherwise, if the compressed size is between half and two thirds of the original size, then FNW will
be used, with one tag bit indicating bit-flipping for every two data bits.
If the compressed size is larger than two thirds of the original size, the block will simply be stored uncompressed
to avoid decompression overhead. No encoding scheme will be applied in this case.
Both encoding schemes will only be applied to the payload, and the header will remain in its original form, such that
the compressed size can be easily computed for decoding, as we will see later.
To indicate whether the block is compressed, one bit tag per block is added to the NVM device to serve as the flag bit.

On read accesses, the controller needs to first determine whether the block is compressed,
and if true, decode the block, and then decompress it. 
An uncompressed block is directly read out and sent back to the requestor.
For compressed blocks, recall that the 24-bit header is stored unencoded, the decoder first uses the header to 
compute the compressed size, and then chooses a decoding algorithm based on the size. The rule is identical to the one 
during encoding: If the 
compressed size is smaller than half of the slot size, then FlipMin is used for decoding; If the size is between half
and two thirds, then FNW will be used.
Finally, the block is then decompressed by 64-bit FPC before it is sent back.
