---
layout: paper-summary
title:  "Parallel Compression with Cooperative Dictionary Construction"
date:   2021-07-07 21:55:00 -0500
categories: paper
paper_title: "Parallel Compression with Cooperative Dictionary Construction"
paper_link: https://ieeexplore.ieee.org/document/488325
paper_keyword: LZ; LZSS; Parallel Compression
paper_year: DCC 1996
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes a parallel compression algorithm with an LZ-family block-referential dictionary searching.
The paper is motived by the three general design goals of LZ-family compression algorithms: High throughput,
good compression ratio, and small block size.
Previous approaches often favor compression ratio more, at the cost of low compression and decompression throughput.
while this paper suggests that by leveraging algorithmic level parallelism, all three goals can be achieved.

The proposed algorithm is from a family of algorithms called the "block referential compression algorithms" that
transforms a block of data B consisting of characters {x1, x2, ..., xn} into a smaller and compressed format. 
In its most general form, the algorithm parses the block B into a series of "phrases" y1, y2, ..., ym.
Each phrase can be either of the type literal phrase, which is only a single character, or of the type copy phrase
of length greater than one, whose sequence of characters match another sequence (the "reference sequence") 
elsewhere in the block.

