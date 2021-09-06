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

The serverless architecture is another improvement over microservices by further abstracting away implementational 
details of individual modules, such as resource scheduling and management, leaving only a function interface for 
invocation. Serverless programmers only need to implement the core functionalities of a service in the form of 
functions, register these functions with the platform, and expect all other mundane tasks, such as fault tolerance,
resource scheduling, instance management, etc., to be automatically performed by the serverless framework.
Serverless functions are typically small and only performs one single task, and does not maintain states across
function invocations. The latter property ensures that the functions can be invoked at any locations given the same
environmental configuration (which is achieved with containers).
This paradigm is often called Function-as-a-service, or FaaS.

This paper assumes the following baseline serverless architecture. The serverless platform is divided into two 
parts, a frontend and a backend. The frontend is also called the API gateway, which is responsible for receiving 
client requests, and dispatching them to the correct functions. The backend consists of function containers, where
each container hosts one function type, and it is assumed that every physical server has all types of function
containers, such that internal function calls can always be dispatched locally (see below).
The function implementations are linked with Nightcore's runtime library, and each function container consists of 
one launching thread and at least one worker thread. The launching thread is part of Nightcore's runtime library, and
it is responsible for spawning and destroying function instances to maintain an optimal level of concurrency. 
Worker threads are simply function instances that can be dynamically spawned or destroyed, and they all execute the 
same function code in the same container.
