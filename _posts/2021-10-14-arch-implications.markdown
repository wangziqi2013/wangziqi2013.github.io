---
layout: paper-summary
title:  "Architectural Implications of Function-as-a-Service Computing"
date:   2021-10-14 23:15:00 -0500
categories: paper
paper_title: "Architectural Implications of Function-as-a-Service Computing"
paper_link: https://dl.acm.org/doi/10.1145/3352460.3358296
paper_keyword: Serverless; Benchmarking
paper_year: MICRO 2019
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents benchmarking results of serverless applications. 
The paper is motivated by the question of whether today's commercial hardware is still a good fit for serverless
workloads, which demonstrate drastically different performance traits than traditional cloud applications.
The paper conducted experiments on real hardware platform with an open-source FaaS software package, and collected
performance statistics with hardware performance counters.
The paper concluded that today's processor design is not exactly optimal for serverless execution, and some 
hardware features need to be reconsidered in order to be fully exploited by serverless.

The experimentation is conduced with Apache OpenWhisk, an open-sourced serverless platform. 
Functions are invoked with external HTTP requests, which are handled by an HTTP reverse proxy, and forwarded to the 
OpenWhisk controller. The controller authenticates the request with a database storing user information, and then 
dispatches the request to one of the worker nodes.
Function instances are wrapped in containers, and they are configured with a maximum amount of runtime memory.
Scheduling decisions are also made with regard to the memory requirement, and function instances with more memory
will be allocated more processor cycles.
OpenWhisk also implements a keep-alive policy that keeps the container instance warm in the memory for a few 
milliseconds after the function completes, after which the container will be swapped out to the disk (paused) to reduce
memory consumption, or terminated (the paper did not mention in what situations these decisions are made). 
This is to reduce cold starts, as future requests that use the same-type container can immediately be fulfilled by the
warm container, rather than starting a new one.

