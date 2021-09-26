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
