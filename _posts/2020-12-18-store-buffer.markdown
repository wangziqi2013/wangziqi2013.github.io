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
reduce such effect on the pipeline, but still leaves much space for optimization. 
