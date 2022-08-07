---
layout: paper-summary
title:  "Frequent value compression in data caches"
date:   2022-08-07 00:43:00 -0500
categories: paper
paper_title: "Frequent value compression in data caches"
paper_link: https://dl.acm.org/doi/10.1145/360128.360154
paper_keyword: Cache Compression; L1 Compression; Frequent Value Compression
paper_year: MICRO 2000
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes Frequent Value Compression in L1 data cache. The paper is motivated by frequent value locality,
a data phenomenon that a small number of frequently occurring values constitute a large portion of a program's working
set and memory traffic.
The design leverages a static dictionary, and encodes values in the cache blocks using dictionary entries. 
Since the dictionary is expected to generally capture a large portion of values in the 
cache block, these values can be represented by the index of the dictionary entry, which needs a smaller number of bits
than the uncompressed value. 
Effective cache size is hence increased by storing two compressed cache blocks into the same slot whenever possible,
achieving a maximum effective compression ratio of 2x.

In order to collect frequent values, the paper proposes using software profiling to scan the memory image of the 
application and identify the most frequently occurring values.
Only a small number of values are needed. For example, the paper suggests that eight values are sufficient to cover
more than 50% of the working set for six out of the ten applications in in SPECint95.
When the frequent values are determined, they are loaded into the hardware dictionary, and will remain there for the 
rest of the execution to serve as the compression and decompression reference.

The paper focuses on direct-mapped compressed caches, but the design principle generally applies to set-associative
caches as well.
each tag array entry is extended with N "mask" field where N is the number of 32-bit words per cache block.
Each "mask" field describes the compression status of the word, as well as compression metadata.
With an eight-entry dictionary, each "mask" field consists of a 1-bit status bit to indicate whether the word is
compressed, and a 3-bit metadata field.
When the word is stored in a compressed form, then the 1-bit status is "1", and the 3-bit metadata stores 
the dictionary entry index that the word is compressed with. 
The word's value is not stored in the data array in this case.
Otherwise, if the word is uncompressed, then the 1-bit status is "0", and the 3-bit metadata stores the offset
of the word in the data array slot.
On a lookup hit, if the cache access requests a word that is compressed, then the value is provided by the 
dictionary, and the data array is not accessed. Otherwise, the value is read from the data array using the 
metadata field.

Tag entries and data array slots still maintain a one-to-one static mapping, i.e., every tag array entry only has
one statically associated data array slot.
To enable the compressed to store more logic blocks than the capacity of the data array, every data array slot
is associated with two tag array entries (i.e., the tag array is 2x over-provisioned).
If both blocks described by the two tag array entries can be compressed to less than half of the slot size,
then the two blocks are stored in the same data array slot. Otherwise, only one tag entry is used, and the block
is stored in completely uncompressed form.

A compressed block is stored in the data array as an array of uncompressed words in that block. Compressed 
words do not need to be stored, as they are already encoded in the "mask" fields of the tag array.
The uncompressed words also do not need to be stored with a per-determined order. In fact, the "mask"
fields for uncompressed words allow them to be stored in arbitrary locations of the data slot, 
as long as the metadata bits in the "mask" fields can address them.
Correspondingly, the cache controller logic must be able to allocate storage of data array slots in word granularity.
