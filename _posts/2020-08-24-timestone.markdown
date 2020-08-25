---
layout: paper-summary
title:  "Durable Transactional Memory Can Scale with TimeStone"
date:   2020-08-24 18:06:00 -0500
categories: paper
paper_title: "Durable Transactional Memory Can Scale with TimeStone"
paper_link: https://dl.acm.org/doi/abs/10.1145/3373376.3378483
paper_keyword: NVM; MVCC; STM; TimeStone; Redo Logging
paper_year: ASPLOS 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents TimeStone, a software transactional memory (STM) framework running on NVM, featuring high scalability 
and low write amplification. The paper points out that existing implementations of NVM data structures demonstrate various
drawbacks.
First, for those implemented as specialized, persistent data structures, their programming model and concurrency model
is often restricted to only single operation being atomic. Composing multiple operations as one atomic unit is most
likely not supported, and difficult to achieve as the internal implementation is hidden from the application developer.

