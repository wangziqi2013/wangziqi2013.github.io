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

The microservice architecture improves over the conventional monolithic services by decomposing large and complicated 
software implementation into smaller tasks, each being easy to solve by a simple module. These modules are only loosely
coupled with each other, and only communicates with a set of external interfaces (rather than raw function calls at
ISA level, as in a monolithic piece of software). This greatly improves the maintainability, availability, and 
flexibility of the software, as each module can be separately implemented and tested with potentially different 
languages and frameworks in the development phase. In addition, microservice modules can also be individually 
maintained as runtime instances in the production environment, which simplifies resource management and isolates
failures, since each individual instance can be managed by the OS independent from other instances.
