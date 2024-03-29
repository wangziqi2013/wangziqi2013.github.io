---
layout: paper-summary
title:  "Serverless Computation with OpenLambda"
date:   2021-10-02 04:25:00 -0500
categories: paper
paper_title: "Serverless Computation with OpenLambda"
paper_link: https://www.usenix.org/conference/hotcloud16/workshop-program/presentation/hendrickson
paper_keyword: Serverless; OpenLambda
paper_year: HotCloud 2016
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This workshop paper presents OpenLambda, an open-source framework (under development when the paper was published) 
that implements the serverless paradigm as an experimental platform for serverless innovations.
The authors of the paper identifies a few features that are critical for performance and usability of the platform, 
and briefly discusses them as potential point of interests that can be implemented in OpenLambda.

The paper begins with a discussion on the current commercial offering of serverless, namely, Amazon Lambda.
Generally speaking, Lambda is a serverless platform that allows individual functions to be uploaded by users, which
will also be individually scheduled anywhere on the cloud, triggered by external events. 
There are two major benefits of Lambda compared with conventional web applications. First, Lambda functions are 
written in high level languages, and the source file is typically small. It is therefore convenient to 
dispatch function code across the cloud, and then start execution with a language interpreter or JIT engine.
Second, no server-side management such as scaling configuration is needed, as these are already covered by the run 
time scheduler which scales out functions by starting more parallel instances to deal with dynamically changing 
workloads. In addition, high-level language functions are less affected by system level configuration differences 
such as library version or compiler compatibilities issues. The language infrastructure requires very little 
specification other than installing third-party packages. 

On Lambda, functions are usually triggered by user-side web applications sending a POST message to a URL.
The request will be turned into an RPC request by a frontend gateway, and then dispatched to the backend worker
node for execution. Functions are started in containers that provide an isolated execution environment, and 
(although not mentioned explicitly in this paper) container processes will be kept alive for a while after the function
completes, which can be reused immediately to serve any new request to the same function on the same worker node 
to avoid the cold start latency. 
The frontend scheduler will also maintain the "sticky route", and dispatches requests to the same function to the 
same worker node to better utilize warm containers.
Multiple instances of the same function can be started in parallel, and these instances are considered as stateless
in a sense that they do not share any run time states except the underlying data storage.
As a result, no consistency guarantee is provided between shared states observed by functions.
Function instances are charged by the memory cap multiplied by the actual time it has executed (rounded 
to 100ms).

To demonstrate the benefit of being able to scale functions without any explicit server management, the paper 
conducted an experiment in which independent RPC calls (that just spins and does nothing else) are made to the 
serverless and conventional containerized platforms, respectively. Results shows that serverless has an obvious
advantage as it could dispatch all the requests to scaled out function instances within a short period of time
and let them execute in parallel, while on conventional platforms, these requests must wait in the queue, and be
handled by the monolithic logic running in the container one by one.

To better understand the request pattern of real-world web applications, and the implications to serverless design, 
the paper also conducted experiment with a web application by treating every AJAX request as a serverless RPC.
Results show that the majority of RPC requests are short and small, which takes less than 100ms to complete.
These requests, if implemented in serverless, will suffer from excessive overcharge as the minimum time unit for 
billing is 100ms on Lambda.
The paper also observes that a small portion of RPC requests last as long as a few minutes, as a result of 
long polling (which allows the serverless to push data to clients, but the action is only triggered by some
other activities).
These RPC calls will also be hugely penalized under the serverless environment, as they mostly remain idle once
started, but they will be charged anyway as they consume memory on the worker node.

The paper then presents a few features that help increasing the productivity and usability of serverless platforms,
which will also be implemented in future releases of OpenLambda. We list these features in a series of bullet points.

1. The execution engine should support efficient instanciation of function instances, since on the current platform, 
   a single instance may take a few seconds to fully start, which is much worse compared with conventional services.
   This effect is most observable when the load is light and not bursty. 
   Caching warm instances solves this problem, but cached instances will consume memory. It is therefore critical
   to find a balance between memory consumption and instance start latency.

2. Lambda functions are written in high-level languages, which could be interpreted or JIT compiled. The latter may
   result in more optimized code, and hence improved execution time. But if a function is only rarely invoked, or
   does not constitute a significant part of total execution time, optimizing the code might be an overkill.
   This is another performance trade-off that OpenLambda must take into consideration.

3. Many functions require third-party packages that are not contained in the language library. The platform should 
   be able to fetch these packages from one of the standard repositories, and cache them locally.
   It is another interesting design decision on which packages should be cached, and which discarded.
   Besides, the scheduler may also take the distribution of cached packages into account when making decisions,
   and can prioritize dispatching functions requiring certain packages to a worker node that already cached these 
   packages.

4. Due to the fact that web applications may issue several RPC requests in the same session to complete a single logical
   task, the platform should enable serverless functions to preserve states across invocations in the form of user 
   cookies.
   Besides, the platform may offer to maintain low-level cross-invocation states, such as open TCP connections, 
   which can be bound to function instances. This enables function instances to talk to the same user session on 
   the web application using the same TCP connection.
   This addresses the second issue in the experiments discussed above: Long polling services on the server side no 
   longer need to be running continuously in the background. Instead, they can be implemented as two serverless 
   functions, with the first one receiving user requests and registering the TCP connection with the framework 
   before it exits, while the second one, which is responsible for server-side data pushing, is started only after 
   the activities it waits for happen.

5. Collaborating with databases is a must-have for serverless. Serverless functions might be executed as user-defined
   functions on an existing database, or as data table iterators that are only triggered when new entires are inserted
   into the table. The latter can be used for monitoring data activities and solve the long polling problem as discussed
   in the previous point.
   In addition, stronger consistency models may also be provided as a plus to enable more collaboration between
   function instances using the data store as a communication channel.

6. The platform should also enable data aggregation, which is the foundation of many big-data algorithms, to be 
   implemented with serverless, in which each leaf-level function instance handles a partition of data,
   and high-level functions summarizes the results from lower level instances. 
   This has two implications. First, functions must be able to communicate in a fine-grained manner to each other.
   Second, the platform should be able to "ship code to data", such that functions are executed on or next to the
   node where data is physically stored, in order to reduce data movement over the network.

7. The scheduler (load balancer) should be aware of multiple locality requirements, such as session locality 
   (instances sharing a TCP connection should be dispatched to the same worker node), 
   code locality (requests should be dispatched to nodes that are likely to contain the code and third-party
   libraries they need), and data locality (instances should be started as close to the physical location of
   data it needs to access as possible).
   Some of these features require that the scheduler know the resource access pattern of functions, which may 
   be prepared by function developers in a manifest file, or exposed dynamically in the run time.

8. Lastly, the new platform should support comprehensive debugging and statistics reporting, such that performance   
   decomposition showing a detailed breakdown of execution times and performance costs. 
   These tools would be of great help in debugging web applications and future innovation.