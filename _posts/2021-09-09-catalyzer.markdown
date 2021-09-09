---
layout: paper-summary
title:  "Catalyzer: Sub-Millisecond Startup for Serverless Computing with Initialization-Less Booting"
date:   2021-09-09 01:49:00 -0500
categories: paper
paper_title: "Catalyzer: Sub-Millisecond Startup for Serverless Computing with Initialization-Less Booting"
paper_link: https://dl.acm.org/doi/10.1145/3373376.3378512
paper_keyword: Microservice; Serverless; OS; Process Template
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Comments:**

1. This paper is very loosely organized and hard to read. While I definitely acknowledge the contributions
   made by the authors, and judging from the author list, it seems that the contributions in this paper have already 
   been applied in industrial production systems, which is impressive and stronger than plain talking.
   But, on the other hand, I do suggest the authors to further think on the motivation and the key insights of the 
   approach, especially the high-level insights, or let's say, what could readers learn from this paper? What is
   the take-away message? I could not find any in this paper.
   Also, I appreciate the individual ideas presented in this paper, and I understand that the authors just applied 
   a series of techniques to reduce startup latency for serverless environment, but these ideas should be more
   organized, and be discussed under a few common topics (e.g., reducing VMM initialization latency, reducing language 
   environment latency, etc.).
