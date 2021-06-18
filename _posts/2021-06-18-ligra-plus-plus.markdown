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

