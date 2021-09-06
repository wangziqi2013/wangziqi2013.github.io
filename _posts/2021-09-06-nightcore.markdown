---
layout: paper-summary
title:  "Nightcore: Efficient and Scalable Serverless Computing for Latency-Sensitive, Interactive Microservices"
date:   2021-09-06 00:48:00 -0500
categories: paper
paper_title: "Nightcore: Efficient and Scalable Serverless Computing for Latency-Sensitive, Interactive Microservices"
paper_link: https://dl.acm.org/doi/10.1145/3445814.3446701
paper_keyword: Nightcore; microservice; serverless
paper_year: ASPLOS 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents Nightcore, a serverless framework optimized for latency and throughput. Nightcore is motivated by 
the two critical requirements of serverless architecture: Latency and throughput. Existing frameworks are incapable of
achieving both at the same time, due to the isolation requirements of function containers.
Nightcore improves over the existing solutions by optimizing certain common operations, such as internal function
calls, message passing, network I/O, and thread concurrency.
