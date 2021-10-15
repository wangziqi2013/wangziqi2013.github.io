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

2. In table 1 the paper claims that they use the five applications listed as the benchmark. Then in 3.2 it is claimed
   that workloads from Python Performance Benchmark Suite is the benchmark. Isn't these two contradicting each other?
   And in the rest of the paper, "json\_dump" and the other few mentioned workload names are all from the latter.

3. There are two different interpretations of LLC not being the performance bottleneck: Either the locality is too
   good (small working sets), or the locality is very bad such that most accesses miss the LLC anyway.
   These two cases are the two extremes of program locality, and the paper should further clarify which case is
   observed in the experiments.
   From the bandwidth study I guess it is the latter, because the memory bandwidth per invocation is higher for 
   cold starts than warm starts, indicating that the LLC is not effective in reducing main memory accesses.

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

By carefully analyzing the performance breakdown, the paper also concludes that the major factor that affects latency is
the queuing delay and container cold start overhead. The former is a natural consequence of local buffering of 
requests before the previous one completes, and the latter is further affected by the status of containers in the 
worker node (paused and unpaused, for example). 
As a result, the OS kernel can contribute to a large portion of the overall delay, especially if containers are 
constantly brought up and down, in which case the OS is frequently invoked to create new processes, perform 
memory management and I/O, and so on.

The paper then studies branch prediction by measuring branch predictor's Misses per Kilo Instructions (MPKI) on
different workloads. Results show that functions that execute for longer time have significantly smaller MPKI,
while those that are shorter have larger MPKI.
The paper argues that it is not because shorter functions are written in a way that is hard to predict, but because
it takes a while to train the branch predictor, and the predictor fails to reach a stable state before the function
completes in the case of short functions.
Besides, for shorter functions, the number of instruction for initializing the container and language runtime is also 
relatively larger, which also aggravates the problem.
The paper suggests that future processors should either be equipped with predictors that take less time to train, or
make the predictor context part of the program context.

The paper also conducts study on LLC and main memory bandwidth. 
To investigate the relation between LLC size and performance, the paper leverages Intel Cache Allocation Technology to 
restrict the amount of LLC allocated to the function process.
For memory bandwidth, the paper uses Cache Monitoring Technology (CMT) and Memory Bandwidth Monitoring (MBM).
Results show that LLC is not the performance bottleneck, because there is not significant performance impact even 
after shrinking the size of the LLC by 80%.
On the other hand, cold starts consume more memory bandwidth than warm starts, due to the cost of the extra 
initialization work that is exclusive to cold starts.
The overall bandwidth consumption at system level when multiple functions are running, however, is still dominated
by the frequency of invocations rather than the per-function overhead: More frequent invocation may prevent cold start
from happening, but on the absolute scale, more concurrently running functions will consume more bandwidth than a few
functions that require more bandwidth for each.

The paper then studies the relation between system capacity, which is defined as the maximum ipc that could sustain
a stable throughput without severely degrading function latency, and the memory size, which is either
the physical memory installed on the worker node, or the amount of memory allocated to the VM instance.
The paper observes that under certain thresholds, the system capacity grows proportionally with the memory size.
But above the threshold, the overhead of managing and scheduling these processes start to become a major source 
of overhead, which degrades performance and results in larger function latency.
This phenomenon is perhaps unique for serverless functions, because the execution time of a typical function is 
comparable with the OS's scheduling quantum.

The paper also noted that there exists a conflict of interest between service provider and users, as the former 
tends to to over-subscribe the system in order to reduce the amount
of physical resources dedicated to serverless, which increases function latency as discussed earlier, while the 
latter favors low latency. In addition, since users are billed by the amount of time spent on executing the
functions, an over-subscribed system also tends to generate more profit for the service provider.
In order to avoid cloud providers exploiting the conflict of interest at user's cost, the paper suggests that the 
billing model of serverless should be changed to only count the number of cycles spent in the application itself,
instead of using both OS time and application time.

Lastly, the paper studies interferences between functions by first starting one function in the balanced mode, 
letting it run for a while, and then starting concurrent instances of a different function at a relatively lower
invocation frequency.
Performance statistics are collected and compared between the two stages.
Results show that concurrent function invocation will move the balanced function to the over-subscribed mode, causing
it to suffer more page faults, context switches, which leads to a significantly lower IPC.
To deal with this, the paper suggests over-provisioning of TLB entries and addition of new mechanism for performance
isolation.
