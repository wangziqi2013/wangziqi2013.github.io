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

**Highlights:**

1. Functions can be chained by registering a DAG with nodes being function instances and edges being the control flow.
   The DAG can be used to generate an execution plan by a scheduler, which is then dispatched to the worker nodes 
   for execution. This way, all functions in the DAG knows the full topology and can work autonomously.

2. Preserving states or passing information across function invocations can be achieved by using a key-value store.
   Accesses to the KVS can be accelerated with a per-worker node cache.

**Comments:**

1. Only static DAGs are supported, and it seems that the scheduler needs to plan ahead before the DAG starts execution.
   This does not work in the scenario where the DAG is dynamic, i.e., which function to call next is dependent on the 
   run time states of previous invocations.
   In addition, this may cause a burst of new instances being created when new requests for large DAGs flood in, as
   the scheduler initializes all instances at once, and simply let them wait for the output of its predecessors.
   I understand that most programs can be transformed to use static DAGs, but still, support for dynamic DAGs 
   would be a nice thing to have.

2. The addressing scheme breaks isolation. If a function can translate arbitrary address into the physical IP/port pair
   and then establishing TCP connection directly to another function, then why do you even enforce isolation?
   Any function in the cloud is able to contact any other function this way.
   A slightly better design would be to always authenticate function's identity on address translation, but this
   cannot fully block malicious functions scanning the IP/port combination. 
   While I do agree that fine-grained communication is critical, the TCP/KVS based communication channel is 
   an overkill and poses great security issues, because it exposes the entire cloud to all instances running on it.
   A better design would be to hard-limit the addressing scheme to only work within the DAG, by, for example,
   software defined networks. But this would be difficult to be implemented in a distributed and autonomous manner,
   which defeats the purpose of serverless and complicates lots of things.

3. The consistency model requires publishing the working set (or at least the read set) between function instances.
   From a transaction perspective this is unnecessary.
   Why not just treat each DAG as a transaction, and gives its a private working space (e.g., stored in the KVS with
   the keys prefixed by the global ID)? The DAG can bring any value it has read into the working space and keep 
   working on that private copy.
   This is basically a concurrency control problem, and lots of elegant solutions already exists. You do not need to
   invent new systems for that.

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
These two consistency models, namely repeatable-reads and causal consistency, expose a well-defined and 
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
failures at any point of the DAG (e.g., make it fail-stop and idempotent, or perform persistent state cleanups), 
and notify the infrastructure to restart execution from the very beginning.
Second, the output of an execution can be returned to the client, either through a message sent back from the API 
gateway like on conventional platforms, or, they can be stored in the KVS and retrieved by the client side application.
Another option is to abstract away the KVS, and provide client side application with the future object. The future 
object listens on the response message or polls the KVS, and, when a read is attempted, will return the result if it 
is already available, or block execution of client side application if results are not ready yet.
Third, function arguments can be references to KVS, which preserves the values produces by previous function 
invocations. As a contrast, in current serverless platforms, function arguments must be passed via messages sent from
the previous function to its successors. The references will be resolved at function invocation time to retrieve values
from the KVS.

When a request is received, it is handled by a scheduler. The scheduler maintains the registrations of all DAGs and 
all functions. If a single function is requested, it simply dispatches the request to the function VM.
Otherwise, if it is a DAG, then the scheduler generates an execution plan according to the functions in the DAG,
by assigning each node in a DAG to an instance on the worker nodes. 
The plan is generated with preferences given to code and data locality. The scheduler tends to assign a DAG node to a 
worker node, if the worker node contains a warm instance of the VM of the function type of the node, or if some 
arguments are KVS references that the node is like to have a cached copy, or both.
The execution plan is then broadcasted to each of the worker node, and these worker nodes will start instances of the 
assigned type (one worker node may be assigned with multiple instances), which wait for their predecessors to complete
before they start execution.
During plan stage, every DAG invocation is assigned a unique global ID, and functions within the DAG are also 
assigned instance numbers, which are also known by all of the participants of the execution plan.
Functions can be addressed individually by other functions in the same DAG using the global and instance ID, which 
will be translated to the physical address, i.e., an IP and port pair that can reach the VM instance hosting 
the function.

Functions communicate with each other by first requesting a translate of the ID, and then establishing TCP 
connections to the peer function.
The paper also noted that functions can use the KVS as a secondary communication channel, if instances cannot 
talk directly (e.g., due to strict isolation): The sending function writes the message into a pre-agreed key value, 
and the receiving function probes the key until a value is written.
In either case, serverless developers may use simple library calls to send and/or receive message to peer functions in 
the same DAG, enabling fine-grained communication between instances.

To accelerate data access on the distributed KVS, which can itself be deployed far from the function worker nodes,
Cloudburst implements LDPC and provides a KVS cache on a per worker node basis. The cache functions like a regular 
key-value cache by fulfilling KVS access requests with much shorter latency and higher throughput, and keeping 
the data it retrieved from the KVS for a while for future accesses. 
The cache also regularly report its cached keys to the scheduler, such that the scheduler can make instance placement 
decisions based on the cached keys. 
Each cache also subscribes from the underlying KVS to receive value updates from the latter. 

Cloudburst uses the KVS to store and maintain metadata and system statistics. For example, the scheduler stores 
function registration, DAG registration, and other system-level metadata in the KVS. Each worker node also
periodically report node statistics such as memory and CPU load to the scheduler by writing these information to the 
KVS. The scheduler may decide to scale up or down a particular function instance and/or worker node, if the 
workload is higher or lower than certain thresholds. 

Cloudburst handles concurrent read/write or write/write accesses to the KVS on the same key with a few different 
policies. Write/write conflicts are handled with what is called "lattice encapsulation", which the paper did not 
elaborate on (I think it just defines some way of replaying updates, like integer addition/subtraction or set 
insertion/deletion can be easily replayed ? I did not read the Anna paper, so do not count on me on this part).
Read/write conflicts, on the other hand, are handled with two possible consistency models.
The first model, repeatable-read, dictates that all function in the DAG either read the same value, if
it has not been updated, or read the value written by the DAG itself after the write is performed.
With local caches, this could be implemented conveniently by just caching the value that is first time read by a DAG
(which is similar to a transaction in this context), and all later accesses to the same key will either read the cached
copy, or update this copy. 
Keys in the working set are published to downstream functions in the DAG, such that their first-time accesses 
to the keys already in the DAG's working set will be redirected to the upstream function's caches to only access 
the private copy, not a potentially different value in the local cache or the KVS.

The second consistency model, namely causality consistency, requires that values be propagated properly between 
functions that are not concurrent (i.e., directly or indirectly connected by an directed path).
In other words, the data dependency of values must be consistent with the control dependency defined by the DAG.
Cloudburst tracks dependencies using Lamport vector clock, and only allows a read to happen if the reader's 
vector clock is strictly larger than a value's clock (I did not quite understand the details in the paper, but
I get the general idea of using vector clocks. You can find discussion on this matter in many other paper
focused on this topic.).
