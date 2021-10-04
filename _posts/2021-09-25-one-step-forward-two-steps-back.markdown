---
layout: paper-summary
title:  "Serverless Computing: One Step Forward, Two Steps Back"
date:   2021-09-25 20:29:00 -0500
categories: paper
paper_title: "Serverless Computing: One Step Forward, Two Steps Back"
paper_link: http://cidrdb.org/cidr2019/papers/p119-hellerstein-cidr19.pdf
paper_keyword: Serverless; Lambda
paper_year: CIDR 2019
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. Despite raising many valid points, I think this paper is mainly complaining about the slow storage / lacking
   more "primitive" or "data-centric" interface for directly accessing high-throughput storage, and lack 
   of communication capabilities between functions. 

**Comments:**

1. While this paper makes a few nicely put points, I think many of them, in fact, partially defeats the purpose of
   serverless, as serverless requires zero management from the programmer. In fact, serverless does not even require 
   that your code to be 100% error-proof, as your code could only be good for 90% of the time, but as long as you are 
   willing to start 10% additional instances, you are still good given that the code is fail-stop and functions are 
   fully decoupled from each other. 
   **This is exactly why serverless is powerful: Nothing cures stupidity, except time, natural selection, and serverless
   computing.**
   The paper proposes that some management work must be done from user's side, such as using DSL or 
   declaring requirements, which contradicts the service goal.

This paper performs a thorough study on serverless and highlights several drawbacks of serverless computing.
The paper begins by observing that serverless has become a popular choice for cloud computing due to its 
support for multitenancy and simplicity of management. To elaborate: On traditional cloud computing platforms,
application developers must build their own project as a whole, deploy the project to the cloud service, and 
be responsible for component interaction and application scaling. The price of cloud service is dependent on 
the type of the platform as well as the start time and the amount of external resource used (disks, databases, network
requests, etc.). 
Serverless, on the other hand, provides a new programming paradigm. Serverless allows individual functions, rather
than complete application logic, to be deployed, and functions are composed dynamically in the runtime to execute the
application's business logic, which is driven by external and internal requests, instead of a pre-defined control flow. 
This enables more flexible development, deployment, and management of the overall application logic, since functions
can be developed, tested, deployed, and instanciated individually, and so does the pricing of functions. 
In addition, serverless functions are supposed to be stateless, meaning that the function does not assume any 
particular states being preserved across invocations, and all essential information for executing the function is passed
by the function arguments. These stateless function often only perform a single task, and produces output by either
sending a message explicitly, or storing the result of computing leveraging some form of storage service.
The blessing of being stateless also enables serverless functions to be scaled easily, as the management framework
can just start more function instances when the load increases, and reduce it when the load falls.
Function instances can be started at any physical machine, as they assume zero state being preserved across 
invocations.
Serverless management comes at no cost from application developer's perspective, as stateless functions only 
communicate with each other and with other cloud services using well-defined interfaces and libraries, and are managed 
by cloud's providers infrastructure.
Multiple serverless function instances from the same or even different applications can be co-located on the 
same physical machine, which are isolated from each other using VMMs or containers.
Again, due to the nature of being stateless and event-driven, serverless functions do not restrict instance placement, 
and can be started anywhere on the cloud.

The paper then figures out three user scenarios that fit perfectly into the serverless paradigm.
The first is embarrassingly parallel applications (here "embarrassingly" means abundantly), in which the functions are 
entirely independent from each other, and each of them can be executed without any communication at all. 
Function instances in this scenario can be easily scaled up and down based on the load, without having to reconsider
synchronization.
The second scenario is to leverage serverless only as a load indicator, and use serverless functions to notify 
the proprietary backend to adjust accordingly. The major body of computing is not performed on the serverless
function, but instead, the backend handles them. Since serverless functions are charged per instance time, this option
is cheaper than running a constant background monitor for auditing.
The last scenario is to compose individual functions to implement the application logic, using functions as building 
blocks or modules. Each function handles a small portion of the business logic, and functions communicate by passing
outputs as the inputs of the next function in the chain.
This use case, in strict terms, is no longer stateless, as states must be logically preserved between function calls in 
the call chain. The actual states are contained in the outputs and function arguments, which can be incorporated 
into the serverless platform with little effort.
The paper noted that, however, this use case may incur huge runtime overhead due to the fact that functions are only 
loosely coupled, without support for efficient state preservation.

The paper then proceeds to point out the limitations of current serverless computing paradigm.
First, serverless is seen by the authors as a "data shipping architecture", meaning that the code is executed on the 
computing node, while data is only pulled from a separate data store to the computing node on demand through the 
network, causing long latency and low data throughput. 
As a contract, conventional data-centric applications typically build their data processing capabilities
around or at least close to the data node, where data can be accessed in a more structured manner.
Second, serverless function instances are not individually addressable, which is a design decision made for easy
scaling and migration, and therefore, it is impossible to build efficient, fine-grained communication channels, which 
are essential to many classical distributed system algorithms. 
Although one may argue that the underlying storage scratchpad may server as a proper communication channel, as the 
storage can be globally addressed by all function instances, the paper indicated that it is also generally not feasible,
due to the low I/O throughout and weak consistency model.
Third, serverless functions are not explicitly managed by the service user, and the cloud provider's infrastructure
is free to schedule a function instance anywhere it finds reasonable. As a result, none of the existing serverless
platforms support specialized hardware, such as GPU or other types of accelerators. 
The paper argues that hardware specialization and acceleration is a future trend that must not be neglected, and hence
it is critical for cloud providers to also provide hardware acceleration capabilities on their platforms.
Lastly, the paper also observes that most open-source software cannot execute unmodified on serverless, since these 
software is developed for managed environment where human operators need to intervene. This may harm open-source 
innovation as serverless users are less interested to try them.

The paper validated the above points using two prototype applications. The first one trains a neural network and 
then uses the trained model to classify texts. The second application simulates distributed leader election, which is a 
common scenario in distributed systems. Both examples show that serverless incurs higher cost and has longer execution 
time. In the first example, the major overhead is reading large chunks of data from the underlying storage for model 
training, since serverless functions must pull data from the persistent storage before each iteration, and push them 
back after the iteration.
In the second example, since there lacks a mechanism for addressing individual functions, the communication between
function instances must be performed by writing to the data service to send a signal, and polling the data service 
to receive a signal.
Both examples prove that the limitations of serverless truly exists, and can become serious performance bottlenecks.

At last, the paper proposes a few challenges for serverless platforms, which, if implemented, can greatly improve their
usability, generality, cost-efficiency, and degree of innovation.
First, serverless platforms should allow functions to be data-centric, and deployed next to high-throughput data store.
This way, accessing data will not become a performance overhead.
To aid this task, the framework may also allow applications to expose its internal data flow and data requirement
using specialized languages or program analysis. Those that require large amount of data transfers could be 
automatically recognized and then deployed, essentially turning it into a "code-shipping architecture".
Second, serverless platforms should support heterogeneous hardware, and enable serverless functions to explicitly
request for these hardware, and make scheduling decisions accordingly. Similar to the previous proposal, the
requirement can also be implicitly derived from program behavior via analysis.
Third, function instances should be made globally addressable, at least within the same application, such that 
fine-grained communication can be realized without using the slower and low throughput storage as the only channel.
Because of the nature of serverless functions, that is, they are prone to be re-deployed and migrated to different
hosts at any moment, the global address must not be bound to a specific physical machines, making traditional addresses
such as IP and ports not a viable option, but more abstracted naming schemes will work.
The fourth and fifth proposals are supports for disorderly and flexible programming, which is about developing new 
infrastructures that enables novel programming languages and techniques be used.
The last two proposals are supporting service-level guarantees and addressing security concerns, which are always 
what people want and are nice to have.
