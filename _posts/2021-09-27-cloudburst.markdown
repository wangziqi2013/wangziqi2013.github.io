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

**Comments:**

1. Only static DAGs are supported, and it seems that the scheduler needs to plan ahead before the DAG starts execution.
   This does not work in the scenario where the DAG is dynamic, i.e., which function to call next is dependent on the 
   run time states of previous invocations.
   In addition, this may cause a burst of new instances being created when new requests for large DAGs flood in, as
   the scheduler initializes all instances at once, and simply let them wait for the output of its predecessors.
   I understand that most programs can be transformed to use static DAGs, but still, support for dynamic DAGs 
   would be a nice thing to have.

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
between function invocations. In addition, the consistency guarantees of the storage service on existing serverless
platforms are pretty weak. For example, two functions on a call chain may read different versions of a value that
contradict causality, which might cause correctness issues as most programs are written with a strong consistency 
model in mind.
Second, function instances are assumed to be independent from each other, and therefore,
there is no way to address individual function instances, preventing fine-grained communication between functions.
On current platforms, this is different to achieve, as functions can be scheduled anywhere on the cloud, and may 
even migrate across invocations, making the conventional naming scheme such as IP and port insufficient. 
Lastly, function composition, the practice of calling other serverless functions within a function instance, is 
slow. This is because all composition invocation requests must be routed to the frontend API gateway, and be dispatched 
just like it is an external request, incurring the overhead of a round-trip time between the frontend and the backend.

Cloudburst addresses the above limitations with three innovative design choices.
First, Cloudburst features what is called "logical disaggregation and physical co-location", or LDPC, meaning that
while, logically speaking, the storage layer is still decoupled from computing layer, and can be regarded as a 
large, unified, and global component providing services to functions via a set of well-defined interfaces, 
the physical implementation of the storage layer is close to the computing layer, and can be often on the same 
physical node.
Cloudburst achieves LDPC with a two-level storage hierarchy. At the global level, a fast key-value store (KVS) is used 
as the global storage for passing or preserving information between function invocations, while at each individual
computing nodes, an extra cache layer maintains high-frequent keys, and enables low-latency access to these keys. 
Second, Cloudburst supports and specifically optimizes over function composition, which enables serverless 
as a more general-purpose computing paradigm, as most general-purpose applications require function modules to
call each other with explicit argument passing and value return.
Cloudbursts model function composition as a DAG representing the control flow and data flow. Function instances 
to be involved constitute the nodes of the DAG, while the invocation relation forms edges. 
External requests can either invoke individual functions just like on conventional serverless platforms, or can 
directly invoke a pre-registered DAG, and expect Cloudburst scheduler (discussed later) to handle function composition.
Lastly, Cloudburst defines and implements two strong consistency models for concurrent accesses of the KVS. 
These two consistency models, namely repeatable-reads and causal-consistency, expose a well-defined and 
intuitive semantics to the functions executing concurrently, which greatly aids program design as most read-write
interleaves can be handled correctly by the framework itself.

We next discuss the operation of Cloudburst in details. The overall architecture of CloudBurst does not deviate far
from conventional platforms: External requests are handled by a frontend API gateway, which are then dispatched 
to worker nodes for execution. Results are returned to the external client after the functions have completed.
There are, however, a few differences that are made to support LDPC and function chaining.
First, since DAGs are executed as a whole, the serverless developers should register the DAG to the cloud infrastructure
by specifying the DAG topology and function input/output. 
User requests may be dispatched to a DAG if the request type is registered to be executed on the DAG.
Cloudburst does not enforce atomicity of DAG execution, meaning that developers should be able to handle execution
failures at any point of the DAG (e.g., make it fail-stop), and notify the infrastructure to restart execution from the 
very beginning.
Second, the output of an execution can be returned to the client, either through a message sent back from the API 
gateway like on conventional platforms, or, they can be stored in the KVS and retrieved by the client side application.
Another option is to abstract away the KVS, and provide client side application with the future object. The future 
object listens on the response message, and, when a read is attempted, will return the result if it is already 
available, or block execution of client side application if results are not ready yet.
Third, function arguments can be references to KVS, which preserves the values produces by previous function 
invocations. As a contract, in current serverless platforms, function arguments must be passed via messages sent from
the previous function to its successors. The references will be resolved at function invocation time to retrieve values
from the KVS.
