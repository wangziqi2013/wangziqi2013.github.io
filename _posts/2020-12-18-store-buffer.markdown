---
layout: paper-summary
title:  "Boosting Store Buffer Efficiency with Store-Prefetch Bursts"
date:   2020-12-18 17:03:00 -0500
categories: paper
paper_title: "Boosting Store Buffer Efficiency with Store-Prefetch Bursts"
paper_link: https://www.microarch.org/micro53/papers/738300a568.pdf
paper_keyword: Microarchitecture; Store Buffer
paper_year: MICRO 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes a store buffer prefetching scheme for handling store bursts. The paper observes that, on data 
intensive applications, the store buffer can incur a significant portion of pipeline stalls due to stores not being
drained in a timely manner. Previous proposals suggest that issuing cache coherence requests for prefetching can
reduce such effect on the pipeline, but still leaves much space for optimization. This paper, on the other hand,
employs a simple state machine to recognize common burst-write patterns, and issues prefetching requests even before
the store operation enters the store buffer. Compared with previous approcahes, this proposal requires less 
stringent timing between the prefetching and the actual access.

This paper assumes a common store-buffer based backend pipeline architecture. Store instructions (or uops) are issued
into the execution unit for address and source operand computation. The store operation can also be added into a 
dedicated structure, called the store queue, but this is irrelevant to the current topic.

