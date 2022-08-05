---
layout: paper-summary
title:  "Cache Compression with Efficient in-SRAM Data Comparison"
date:   2022-08-05 01:36:00 -0500
categories: paper
paper_title: "Cache Compression with Efficient in-SRAM Data Comparison"
paper_link: https://ieeexplore.ieee.org/document/9605440/
paper_keyword: LLC; Compression; In-SRAM Compression
paper_year: NAS 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes in-SRAM data compression, a novel cache compression technique that leverages the 
physical organization of SRAM storage elements to perform compression and indexing of compressed data.
The paper is motivated by the fact that most existing cache compression designs only treat the data array
as a scratchpad, and base the design on such an abstraction. In reality, however, the cache's data array
is not a flat storage structure, but instead, consists of smaller units that can be separately addressed
and may share control and/or data signal. 
The storage organization of caches can complicate a seemingly simple design using the flat storage abstraction,
because data is indexed in a particular pattern that may or may not be compatible with the access pattern
required by the compressed cache.
Besides, in these designs, the unit of compression is typically cache blocks. If a cache block is 
compressed using another block as the reference, then both blocks must be fetched and decompressed 
at access time. Both operations will incur extra latency on the read critical path, and as a result,
the benefits of compression diminish.

This paper proposes a different way of performing compression, which builds compression and decompression 
logic within the SRAM access logic. Besides, the unit of compression is designed in a way that is consistent
with the granularity of storage and data indexing, which both simplifies the design, and allows finer grained 
compression.

The compression design is based on the last-level cache organization in Xeon processor, which we describe as follows.
In Xeon, the LLC is partitioned into slices by cache sets, and each core has its own slice.
Each cache slice can be considered as a separate cache in our context, because each slide has its own storage 
elements and access logic.
Each way of a slice is implemented as a column, which contains all sets in that way, and each column is 
divided into four banks. 
