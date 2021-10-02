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
