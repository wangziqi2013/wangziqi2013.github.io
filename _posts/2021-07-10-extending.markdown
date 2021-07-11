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

This paper proposes a technique for reducing storage overhead of applying data encoding to reduce bit flips of 
NVM writes. 
As NVM devices have limited write-erase cycles, and are generally more power-hungry for writes, previous works have 
focused on reducing the number of bit flips per write by encoding the data block to be written.
These schemes, however, generally require metadata tags for each block on the NVM, incurring storage overhead.
For example, Flip-N-Write performs the best when every two bits of data is accompanied by one bit of metadata bit
to indicate whether the two-bit unit is flipped, causing a 50% storage overhead.
In FlipMin, the storage overhead can even be as high as 100%, meaning that the amount of storage doubles for storing 
the same amount of logical bits. FlipMin re-encodes words in the input block to longer words, such that each raw 
word has several different representations. The appropriate representation is then chosen to minimize the number of
bit flips on the location to be written. 

