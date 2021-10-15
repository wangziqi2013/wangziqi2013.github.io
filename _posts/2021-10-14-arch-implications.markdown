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

**Comments:**

1. I got confused at figure 4 because the x axis says "invocation time". I think a better term would be "wall clock 
   time since experiment started", meanwhile "invocation time" sounds like the inverse of invocation frequency.

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
Each worker node has a local queue that buffers requests dispatched to the node, which is serviced collectively by all 
container instances running on the node.

The first experiment is to explore the relation between function latency and the invocation frequency.
A driver keeps sending requests to the worker node at different frequencies, denoted as invocation per cycle (ipc), and 
the wall clock latency of the invocations are recorded. 
Results show that there are three possible scenarios. In the first scenario, the speed of arrival is higher than 
the speed of handling. Requests will start to accumulate in this case, which causes latencies to grow as the queue 
becomes longer. The paper calls this case as "over-invoked".
In the second case, the frequency is too low, such that containers are likely terminated or paused after handling a 
request, before the next request arrives. In this scenario, the latency of functions vary depending on the status 
of the container when the request arrives, and hence both short and long latency can be observed.
This scenario is called "under-invoked"
In the third case, the speed of request arrival and the speed of request handling match, such that a constant 
throughput can be maintained, and therefore, functions also have a constant latency.
This is the "balanced case".
The system capacity can be determined as the maximum ipc when the system is in a balanced case. Note that the balanced
case is not an exact ipc value, but rather, a range of ipc values that achieves stable latencies.


