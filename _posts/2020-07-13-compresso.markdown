---
layout: paper-summary
title:  "Compresso: Pragmatic Main Memory Compression"
date:   2020-07-13 19:10:00 -0500
categories: paper
paper_title: "Compresso: Pragmatic Main Memory Compression"
paper_link: https://ieeexplore.ieee.org/document/8574568
paper_keyword: Compression; Memory Compression; Compresso
paper_year: MICRO 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Metadata mapping can be performed by direct mapping into a reserved address space of physical DRAM. The overall overhead
   is as low as 1/16 of the address space (assuming 64B to 4KB mapping).

**Lowlight:**

1. Although the paper delivers its ideas without any missing parts, it can be more structured and organized. For example, 
   there is no mentioning of the metadata cache until Sec. IV.B.2, and neither after.
   Rather than proposing and describing a research prototype, this paper is closer to evluating different ideas of 
   main memory compression, realizing the trade-offs, making the correct design decisions, and finally assembling
   all aspects together into a working memory compression scheme.

This paper proposes Compresso, a main memory framework featuring low data movement cost, low metadata cost and ease of 
deployment. The paper begins by identifying two issues with previous memory compression schemes. The first issue is 
excessive data movement, which is not only a major source of negative performance impact in many cases, but also often ignored 
due to careless evaluation. Data movement is needed in several occasions. When a compressed cache line is written 
back, if the compressed size is larger than the physical slot allocated for storing the old compressed line, then 
the rest lines after the dirty line has to be shifted towards the end of the page to make more space. In addition, if
the sum of compressed line sizes exceed the total page capacity, a larger page should be allocated, and all compressed
lines in the old page should be copied over to the new page.
The second issue is OS adoption. The compressed main memory scheme may be abstracted away from the OS, which leaves
the OS unmodified when deploying the scheme, suggesting easier adoption. It is, however, also possible that the OS 
is aware of the underlying compression, and will accommodate by allocating different sized pages, manipulating extra mapping 
information for compressed pages, and reallocating pages on hardware request. The paper argues that a transparent compression
scheme is better, since it encourages adoption and minimizes OS migration cost.

The paper then identifies four important design choices and trade-offs it makes. The first is the compression algorithm.
The paper selects Bit-Plane Compression (BPC) as the cache line compression algorithm, due to its simplicity and higher
compression ratio. BPC combines BDI, FPC and RLE by first transforming the input symbols with BDI-style delta, bit-plane 
rotation, and bit-wise XOR to generate as many zeros as possible, and then compressing the resulting stream with low 
entropy with either FPC or RLE. The paper slightly modifies BPC such that the transformation is not always applied. The
compressor always compares BPC with directly applying FPC + RLE without the transformation to further avoid pessimistic
cases with BPC. 

