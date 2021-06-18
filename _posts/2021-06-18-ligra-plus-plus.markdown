---
layout: paper-summary
title:  "Smaller and Faster: Parallel Processing of Compressed Graphs with Ligra++"
date:   2021-06-18 01:00:00 -0500
categories: paper
paper_title: "Smaller and Faster: Parallel Processing of Compressed Graphs with Ligra++"
paper_link: https://ieeexplore.ieee.org/document/7149297
paper_keyword: Compression; Graph Compression; Ligra+
paper_year: DCC 2015
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Using delta encoding to compress sorted adjacency list; The diffs are likely to be smaller than a full 
   32-bit word if edges are clustered.

2. k-bit blocks similar to UTF-8 can be used to encode a value in variably sized code words.

3. Using group run-length byte code rather than individual byte codes. A header describes the number of k-bit blocks
   for a certain number of encoded words. This enables parallel decompression.



This paper presents Ligra+, a compressed graph library based on Ligra.
Despite the fact that graph compression has been attempted from multiple directions, the paper points out that it is
still an interesting topic that is worth studying for two reasons. 
First, as more and more computation tasks nowadays have been moved to the cloud, it becomes crucial to reduce the 
memory footprint of these tasks, as cloud platforms often charge customers by the amount of memory consumed on the 
computing node.
Second, previous proposals often only consider sequential graph algorithms, missing the opportunity of parallelization.
Ligra++, on the contrary, is designed for parallel computation on the compressed graph.
The paper also noted that, since graph computation is memory bound, compression helps reducing the memory bandwidth
required to fetch the same amount of information from the memory to the cache hierarchy. 
As a result, more parallelism can be extracted. In addition, since for most of the time, the processor will be 
waiting for cache misses rather than executing arithmetic instructions, the paper argues that the increased number 
of instructions for runtime decoding will likely not become a significant factor to performance.

Ligra+ is based on Ligra, a graph processing framework, which we describe below. Ligra is designed for the most general
possible user scenario, i.e., directed graphs with real value edge weights. 
Vertices are represented by integers from 0 to (|V| - 1), where |V| is the total number of vertices in the graph.
Edges are represented by per-vertex adjacency lists. Each vertex has two adjacency lists for representing outbound and 
inbound edges.
In each adjacency list of node v, the other end of the edge u is stored, such that (v, u) or (u, v) (depending on whether it is outbound or inbound nodes) is a directed edge of the graph. 
The order of storage does not matter, and is thus undefined in Ligra.
The in-degree of a vertex is defined as the number of edges entering the vertex, which equals the size of the 
inbound adjacency list. Similarly, the out-degree of a node is defined as the number of outgoing nodes, whose 
value equals the size of the outbound adjacency list.
Ligra assumes that there is no self edge and duplicated edges.
Edge weights are mapped from an edge (which is specified using the vertex number, the list, and the index in the list)
to a real value by a mapping function. The implementation of the function is unspecified, and is irrelevant to 
this paper.
Simpler graphs, such as uni-direction graphs or uniform weighted graphs can be encoded more efficiently by only
storing one adjacency list per vertex and by not having a edge weight mapping function.

Ligra supports vertex subset data structure. There are two different flavors. A dense vertex subset is represented 
as a bitmap of |V| bits, in which each bit represents one vertex. A sparse vertex subset is simply an unordered list
of vertex numbers, the size of which is linearly proportional to the number of nodes in the set.

Ligra supports two graph bulk operations. The first is vertex map, which applies a given function F to each vertex in
a vertex subset, and returns another subset containing nodes for which the function F returns true. 
The function F can potentially alter the vertices. 
The second is edge map, which applies a function F to all edges (u, v), where u belongs to the given vertex 
subset, v is adjacent to u, and C(v) is true for a given condition function C. Similarly, F may update both u
and v. The output of edge map is a vertex subset containing nodes for which F returns true.

The implementation of the vertex map operation is quite straightforward: The sequential version just iterate over
the vertex subset and applies function F to each vertex in the set. The parallel version uses cilk plus to parallelize
the iteration loop.
The edge map has two implementations. If the sum of outbound degrees of nodes in the vertex set exceeds a certain
threshold (by default, |E| / 20), the dense edge map is used. This implementation is similar to the "pull" model
of many graph algorithms. It iterates over all nodes in the graph, and for each node v, C(v) is first called to test 
the condition. 
If the condition passes, all *inbound* edges (u, v) where u belongs to the given vertex set are tested with function F, 
and node u is added to the output set.
The sparse implementation, on the other hand, uses a "push" model. It simply iterates over the given vertex set,
and for each node u, it enumerates all *outbound* edges (e, v), and tests v with function C. If the test passes,
F(u, v) is called and output is generated accordingly.

Ligra+ optimizes over Ligra by compressing the adjacency list. The list is first sorted, and then compressed with
delta encoding. To elaborate: given a sorted adjacency list of node u v0, v1, v2, v3, ..., compression is performed by 
first taking the deltas, which produces (v0 - u), (v1 - v0), (v2 - v1), ..., and then these deltas are encoded with 
variably sized code. The paper proposes two coding schemes. 
The first one, called a k-bit code, encodes a value into a sequence of k-bit blocks. The value is divided into one
or more (k - 1) bit segments, and each of them is encoded by a k-bit block.
Each k-bit block uses the highest bit as the continuation bit, which indicates whether there is a next block, or
the current block is the last one. This scheme is similar to how UTF-8 encodes a 32-bit Unicode character.
The decoder is straightforward: just read in k bits for each iteration, and combines the lower (k - 1) bits into
the decoded value. If the highest bit of the block is 1, then the iteration continues to the next block.
Otherwise, the value is fully decoded.

The second scheme optimizes over k-bit code by encoding several values that use the same number of blocks together
in the same group. Each group has a 1 byte group header, where 2 bits of them are used to indicate the number 
of blocks in the encoding, and the rest 6 bits are used to represent group size. 
The decoder can thus decode values in a group in parallel, since each code word starts at a known offset.
This is called run-length encoded byte codes in the paper.

The paper also noted that the first value in the list of deltas may be negative, while the rest is always 
positive since the list is sorted. The first delta value, therefore, is encoded with the sign bit, while the 
remaining deltas are treated as unsigned values.

The compressed code words of all vertices are stored in a single array compactly. Two arrays are needed for inbound
and outbound edges in a directed graph. To enable random accesses of the adjacency list of any node, an extra
offset array is also added for each compressed code word array. Each element of the offset array stores the offset
of the adjacency list for the corresponding vertex.
The inbound and outbound degree of vertices as well as edge weights are also stored in separate arrays. 
Weights may also be compressed using the same delta encoding scheme.

The paper also notices that edges are not distributed evenly across vertices, and therefore, parallel processing
at vertex level will likely not result in performance improvement, since a few vertices with high degrees may
become the performance bottleneck. To deal with this, the paper proposes that more offset entries be inserted 
for vertices whose inbound or outbound degree exceed a certain threshold (e.g., 1000), more than one entry
will be added into the offset array for this node such that random accesses are also supported at the middle 
of the node's adjacency list. This enables graph algorithms to process edges of vertices with large degrees in
parallel, which distributes works more evenly.
