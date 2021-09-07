---
layout: paper-summary
title:  "Put the "Micro" Back in Microservice"
date:   2021-09-06 21:45:00 -0500
categories: paper
paper_title: "Put the "Micro" Back in Microservice"
paper_link: https://www.usenix.org/system/files/conference/atc18/atc18-boucher.pdf
paper_keyword: Microservice; Serverless; Linux
paper_year: USENIX ATC 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes a mechanism for optimizing microservice and serverless latency. The paper is motivated by the 
fact that existing isolation mechanisms, while ensuring strong safety and fairness of scheduling, incurs long latency
for their heavyweight, process-based resource management. This paper seeks to reduce the latency of microservices
and serverless using a different service execution model with reduced isolation, with the safety of execution being 
enforced by a combination of language type checks and special system configurations.

The paper observes that tail latency is a serious issue for serverless applications, because the user experience of 
interactive applications depend on the tail latency of the slowest of all the components. 
Conventional microservice and serverless frameworks incur excessive overhead by encapsulating each microservice
instance as a separate process (or container process), and invokes a new process every time a request is dispatched.
This approach, despite having strong isolation between different instances as provided by the OS and the virtual memory
system, suffers two types of inefficiencies. First, processes are rather heavyweight, and the spawning and destruction
of processes will consume resources. As a result, for cold-start processes, they take significantly longer latency than,
for example, loading a shared library into an existing process, making it a major overhead for process-based serverless 
instances. The second type of inefficiency is the overhead of process themselves, including scheduling, state management, etc., (actually, the paper did not discuss in detail what are the source of inefficiencies, so I made a few
educated guesses), which is type of overhead users need to pay for even if instances are spawned from a thread pool
instead of with cold-start.