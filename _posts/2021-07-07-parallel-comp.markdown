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
The latter does not need to be stored explicitly in the compressed stream, as it can simply be encoded by storing a
reference to the reference sequence within the block.
The algorithm then encodes the two types of phrases as follows.
Literal phrases are encoded with a pair (0, c), in which the first component is a single bit serving as the flag,
and the second component is the character constituting the phrase, and is stored explicitly (the algorithm may
further encode the character using Huffman encoding, but it is out of the scope of the block-referential algorithm).
Copy phrases are encoded as a three-component tuple (1, P, L), in which P represents a pointer to the reference 
sequence in the block, and L is the number of characters. 

One thing to note is that, although phrases are always non-overlapping and must cover the entire block, 
a copy phrase may well overlap with the reference sequence (but not with itself), such that some characters are 
in both sequences.
From another perspective, a sequence may also overlap with more than one phrases that are encoded by the algorithm.
Whether the encoding with a copy-phrase referring to a sequence that partially overlaps with the phrase itself is 
able to be compressed is dependent on both the decompression algorithm, and the data dependency, as we will see below.
