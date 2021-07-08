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

One of the most important properties of the above formalism is that compressibility does not always imply 
decompressibility. In other words, a block may be successfully compressed by having copy phrases making circular 
references, but this produces ill-formed results, which is definitely not decompressible due to not being to resolve
the data dependency.

The paper proposes two graph-based formalisms to determine decompressibility.
The first is called "phrase decodable", in which a graph G is constructed using phrases as nodes, and references 
between phrases as edges. In the graph G, if a phrase yi refers to a sequence that overlaps with one or more 
phrases yj, yk, ..., then an edge is added from nodes that represent yi to yj, yk, ..., meaning that phrase yi
must be decoded after yj, yk, ..., have been decoded. 
Note that in this model, a sequence can overlap with multiple phrases, as sequences do not necessarily correspond 
to phrases. If the sequence overlaps with the phrase yi, then there is a self-dependency, meaning that the 
block could not be decompressed.

The second formalism is called "character decodable", which is similar to the first one, except that graph nodes 
are characters in the uncompressed block, and edges are character dependencies. 
Two characters ci and cj is connected by an edge, if and only if ci is in a phrase, and cj is in a sequence referred
to by the phrase, and that they are on the same offset from the beginning of the phrase or sequence. 

Decodability of a compressed block can be inferred from the graph with a simple rule: If the phrase decodable graph
contains a cycle, then the block is not phrase decodable. Similarly, if the character decodable graph contains a cycle,
then the block is not character decodable.

A phrase decoder begins from a node with no outgoing nodes. Initially, the node must be a literal phrase, 
since all copy phrases must refer to some sequence and therefore have at least one outgoing edge. 
Then the decoder outputs the literal on the corresponding offset (indicated by the position of its tuple in the
compressed stream). The node as well as edges pointing to it are then removed.
Next the decoder repeats the loop: Select a node with no outgoing edge. If the node is a literal phrase, just decode
it as a character. Otherwise, follow the pointer P to the output buffer, and copy L characters starting from the 
pointer to the corresponding offset of the copy phrase. Both nodes and edges are removed once the node is processed.
Decompression completes when all nodes are processed.

The most important thing about the edge decoder is that it cannot process the case where a sequence overlaps with a
copy phrase. In this case, the graph contains a self-cycle, as the node that represents the copy phrase will have
an edge pointing to itself.

A character decoder operates almost in an identical way as the phrase decoder, except that it always decodes 
characters by either outputting it, if it is a literal phrase, or copy a single character from the node it points to,
if the node belongs to a copy phrase.
Nodes in character decodable graphs must have only one outgoing edges, if any, since edges are formed by connecting
character nodes in the copy phrase and the referred sequence.

A general decoder as described above needs to randomly access the decoded stream and the output buffer. 
In many scenarios, this is considered inefficient, and programmers want to implement an algorithm that can decode 
the block in one pass and only performing streaming reads and writes.
To achieve this, the paper proposes that the graph can be slightly modified by adding backward edges from a node to
all nodes that are before it in the stream of phrases.
This essentially restricts that decompression must process the stream from left to right, because otherwise, the 
artificial dependencies will be violated.
