---
layout: paper-summary
title:  "FaaSCache: Keeping Serverless Computing Alive with Greedy-Dual Caching"
date:   2021-09-30 21:04:00 -0500
categories: paper
paper_title: "FaaSCache: Keeping Serverless Computing Alive with Greedy-Dual Caching"
paper_link: https://dl.acm.org/doi/10.1145/3445814.3446757
paper_keyword: Serverless; FaaSCache; Caching Policy; Greedy-Dual Caching
paper_year: ASPLOS 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents FaaSCache, a caching policy for virtual machine keep-alive in multi-tenant environments containing
heterogeneous function instances. The paper is motivated by the fact that commercial cloud providers nowadays all
cache function instances on the worker node to alleviate the long cold start latency, which is incurred by the 
initialization cost of the container itself and the language runtime. The caching strategy, however, has not been 
well-studied, leading to simple but sub-optimal design decisions such as the naive expiration mechanism.
This paper draws an analogy between the function caching problem with a more traditional and broadly studied problem 
of caching variable sized objects, and proposes better policies for function caching and VM over-provisioning.

FaaSCache is built upon the concept of function keep-alive, which has now become a standard practice for cloud 
providers to not terminate the container or VMM instance (we use the term "container" below to refer to both)
after the function completes. Cloud providers keep function instances alive for two reasons.
First, containers themselves incur the overhead of booting a system (for VMM), or setting up the isolated environment
(for containers). Second, the language runtime is also likely to take time to initialize, including downloading and 
importing library dependencies. 
By keeping the container instance alive after execution, and hosting the same function the next time a request arrives,
the so-called cold start overhead can be avoided, and functions generally will have shorter latency from being
requested to being completed, which is a desired feature as serverless functions are typically small.
