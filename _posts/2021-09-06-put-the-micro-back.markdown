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

**Comments:**

1. If processes are constantly running (including being scheduled out by the OS for being blocks on IPC 
   calls), shouldn't this affect the billing of the serverless infrastructure? 
   Because there is something that is always running which might be considered by the FaaS provider as consuming 
   resources?
   Or, this is actually part of the infrastructure used by FaaS provider, so billing is conducted based on how
   the microservice modules execute, not based on the worker process? <--- I think this is the proper explanation

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
instances. The second type of inefficiency is the overhead of process themselves, including scheduling, state 
management, etc., (actually, the paper did not discuss in detail what are the source of inefficiencies, so I made a few
educated guesses), which is the type of overhead for which users need to pay even if instances are spawned from a 
thread pool instead of with cold-start.

The paper hence proposes a different way of managing microservice instances, which we describe as follows. 
The paper assumes that an API gateway acting as the frontend handles all network I/O, and is responsible for managing
requests and responses. 
Instead of spawning new processes or selecting from a thread pool when new instances are to be started, each core
now has a worker process pinned on that core, which is capable of executing the microservice code (functions) for all 
microservices.
The worker process can dynamically load and unload microservice code as dynamically linked libraries using existing 
OS mechanisms. Microservice modules can even be pre-loaded to avoid paying the cold-start overhead, at the cost of
extra memory usage by the module. Application functions are registered to the worker process by their names, 
which is also specified in the client request. A table of registered functions and their module paths are maintained
by worker processes, such that the corresponding function implementation can be found in the run time.
Worker processes do not spawn new processes of threads to execute the microservice code. Instead, they simply
perform native function calls to the requested routine, and only process one request at a time (i.e., the next request
can only be serviced after the current one returns).
Microservice instances are invoked on receiving a request from the frontend API gateway. The gateway allocates a 
message buffer for each of the worker process, and both components use the buffer as a channel for sending 
requests and responses with shared memory IPC.
When a worker process becomes idle, it will be blocked on the IPC call for attempting to read a new message from
the channel, and then be scheduled out by the OS.

The above arrangement, despite having better latency than the conventional approach, has two flaws regarding isolation.
First, microservice instances are no longer isolated with the worker process.
The worker process hence risk being corrupted, crashed, or maliciously attacked by the microservice module (e.g.,
with common mistakes such as NULL pointers, dangling references, etc.),
since the former loads the latter as a dynamic library and both will execute on the same address space with the same 
resource.
Second, since requests are processed one at a time on each worker process, a malfunctioning or malicious function
can monopolize the CPU resource by never completing. This scenario can essentially turn into a DoS and is fatal to
the entire system.

To address the first flaw, the paper proposes that type-safe and statically checked languages, such as Rust, be used
to implement the microservice module. Rust performs compile-time pointer checks to ensure that all memory references
are valid and will not cause system crash or access data that is not supposed to be accessed.
In addition, to avoid the microservice invoking arbitrary system calls, such as exit(), the worker process will use
seccomp() system call after initialization to block most system calls, only leaving the essential ones available for
the microservice module to use.

To address the second flaw, the paper proposes that microservice functions should be assigned an execution quantum
(which is derived from the desired latency and the number of cores), and be preempted after its execution quantum has 
been used up. To preempt the user-provided function, worker processes use high-precision system clocks (which is
initialized before invoking the function) to send a SIGALARM signal to the function. The Rust implementation must 
properly handle SIGALARM by jumping to the point of execution, and unwinding the stack to deallocate all heap objects,
after which the function can elegantly exit.
