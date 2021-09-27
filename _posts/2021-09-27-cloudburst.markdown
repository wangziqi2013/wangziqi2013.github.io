---
layout: paper-summary
title:  "Cloudburst: Stateful Function-as-a-Service"
date:   2021-09-27 01:16:00 -0500
categories: paper
paper_title: "Cloudburst: Stateful Function-as-a-Service"
paper_link: https://dl.acm.org/doi/10.14778/3407790.3407836
paper_keyword: Serverless; CloudBurst; Key-Value Store
paper_year: VLDB 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents Cloudburst, a serverless framework that allows functions to preserve states between invocations
by using a distributed key-value store with strong consistency guarantees.
This paper is motivated by the fact that today's serverless frameworks only provide stateless functions, which disallows
communication between functions for the ease of scaling and management. 
Cloudburst addresses the limitation with a global key-value store serving as the persistent state storage across 
function invocations, combined with a per-instance cache for low-latency access.
Cloudburst also implements a distributed consistency model that enables concurrent accesses of shared states by 
different functions, which also turns the key-value store into a fast communication channel.

The paper begins by pointing out that disaggregation, the practice of separating computing and storage components of 
the cloud service, has limited the usability and efficiency of serverless functions. On the one hand, by decoupling 
computing nodes from the storage nodes and allowing the former to scale freely, it is made possible to adjust the 
computation density of serverless functions by changing the number of instances according to the dynamic workload,
and to charge cloud service users only based on function invocations, i.e., the actual amount of services provided, 
rather than with a fixed rate over a period of time. 
On the other hand, however, there are a few drawbacks of today's serverless paradigm.
First, storage access latency is too high to be practical as a persistent medium for passing or preserving information 
between function invocations. Second, function instances are assumed to be independent from each other, and therefore,
there is no way to address individual function instances, preventing fine-grained communication between functions.

