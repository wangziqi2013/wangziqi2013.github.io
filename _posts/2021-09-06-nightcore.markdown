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

We next describe the additional components added by Nightcore. Nightcore runs an engine process in the background
that serves as a central coordinator and message hub for all functions as well as for external requests. 
The engine reads network I/O messages using a few threads listening on the socket file descriptor, and these threads
are event-driven for processing throughput, meaning that they do not spawn new processes to handle client requests,
but instead, they simply dispatch received messages to the corresponding message queue.
For each function container, the engine allocates a message buffer holding the requests for function invocation,
and it dispatches these messages to the functions by invoking the function on one of the idle worker threads.
The engine tracks the current number of worker threads in each function container, and tracks their activity status.
Message dispatching is only performed when there is an idle thread available in the function container, which
implies that the functions do not need any extra buffering for incoming messages.
One thing that worth noting is that the message queue stores function invocation requests for both external 
and internal requests. These requests are passed to the functions with different APIs, such that the response
can be sent correctly.

Messages are passed between the engine and worker threads using a combination of named pipes and shared memory IPC.
If the message (header and body) is smaller than 1KB, then they are only passed between the engine and worker threads
using the named pipe. If, however, that the message payload is larger than 1KB, which is rare but still possible,
then the payload will be passed via shared memory IPC, while the message is still passed through the named pipes.
During execution, worker functions will block on named pipe reads when they are idle, and become invoked when a 
message is received on the named pipe. The engine, on the other hand, simply writes the function invocation 
request into the named pipe, and changes the status of the function to active.

The next contribution of Nightcore is optimization on internal function calls.
Internal function calls are defined as function calls made by one of the serverless functions, 
rather than being requested by clients. Theoretically speaking, internal function calls do not need to go through the 
frontend API gateway, since they can be
satisfied locally by directly calling the function. Today's serverless framework, however, has no such optimization.
Nightcore optimizes internal function calls by dispatching them directly to the engine without involving
the frontend. Since the engine has a message queue for each function container, this would be no different from
calling the function via the frontend, except the assumption that every physical server must have all types of 
function containers, because otherwise, an internal call would not be able to locate the local instance.

Nightcore also adjusts the degree concurrency dynamically. In serverless architectures, multiple instances of the
same function can be spawned, and each of them can be working on independent tasks.
If functions are allowed to be spawned arbitrarily without limiting the maximum degree of concurrency, a sudden
surge in the workload may cause an exponential growth in the number of active function instances, especially if
internal function calls are frequent. This will quickly saturate the system resource available, and eventually 
harm performance with an over-subscribed system.
Nightcore avoids this by limiting the number of concurrent instances each function container could host.
The information is communicated to the launching thread in every container, which is part of Nightcore's runtime,
and the launching thread dynamically adjusts the degree of parallelism by spawning or destroying worker threads.
The spawning and destruction of worker threads are implemented with a thread pool, with threads being created 
on spawn requests, and destroyed only when the number of thread contexts in the pool exceeds a certain threshold.
Nightcore limits the maximum degree of concurrency to the product of average request throughout and average 
request service time (which is the number of requests that would have been accumulated during the service time).
Both the request throughput and the service time are monitored and updated by the engine in a regular basis 
(the engine tracks function latency with timestamps). 
