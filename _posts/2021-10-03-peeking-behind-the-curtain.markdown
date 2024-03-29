---
layout: paper-summary
title:  "Peeking Behind the Curtains of Serverless Platforms"
date:   2021-10-03 04:49:00 -0500
categories: paper
paper_title: "Peeking Behind the Curtains of Serverless Platforms"
paper_link: https://www.usenix.org/conference/atc18/presentation/wang-liang
paper_keyword: Serverless; AWS Lambda
paper_year: 
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents benchmarking results on three serverless platforms and the performance and security implications
of these results. The paper's experiments consist of various tests and functional benchmarks, and reveals 
several critical design decisions and performance characteristics of serverless platforms that were never made public 
to users. The paper serves as both a comprehensive user experience report, providing valuable insights for peer 
serverless function developers to plan and optimize accordingly, and as a guideline for future iterations of these
platforms.

The paper begins with a background review of the platform under discussion. In this summary, we focus on AWS Lambda,
since it is the current de facto standard of serverless computation, while the other two has not gained as much market
share and recognition compared with AWS Lambda. 
The serverless platform allows users to upload and configure individual functions written in various high-level 
languages, and each function will be invoked individually by external events, distinguishing the serverless platform
from traditional cloud platforms where services are long-running and monolithic pieces of software whose scalability
depends on the implementation and thus must be carefully tuned.
Multiple instances of Lambda functions could be invoked in parallel, and the scheduler may handle traffic surges by
either queueing the requests or starting more instances, with the latter resulting in better scalability.
Lambda functions are billed also individually per invocation, based on the resource consumption such as CPU time and
memory usage.

The paper also briefly discusses the internals of AWS Lambda. The requests are handled by an API gateway frontend,
which queues and dispatches the requests to the backend worker nodes. 
Each cloud user's account is called a "tenant" in this paper, and functions belonging to several different accounts may 
co-locate on the same physical machine or even virtual machine (the paper disproves the possibility of the latter, 
though), which is referred to as "multi-tenancy".
Worker nodes use virtual machines to isolate different tenants, and within each VM instance, functions started by
the same user are isolated using containers. The paper uses the term "function instance" to refer to the container
process rather than each function invocation. **In this summary, we slightly change the usage of words, and we refer
to container instances as "container processes", and reserve the term "function instance" to address individual 
functions.** These two concepts are not necessarily identical, since a container instance may be kept alive after the 
function completes, and reused for future requests. AWS Lambda, in fact, implements this optimization to reduce cold
start latency, which is incurred by container and language runtime initialization overhead.
Container processes are allocated ephemeral storage on the disk as scratchpads. These ephemeral storage will be freed
after the container process exits, but will be preserved if the process is kept running.
This feature is leveraged in this paper to detect whether multiple function instances share the same container 
processes. The first function instance ever started within the container creates a file and writes its unique 
invocation ID to the file, and later invocations just check whether the file exists, and if it exists, reads 
the ID before overwriting it with its own.
In addition, physical machines can be identified by reading the procfs file /proc/self/cgroup, and the host machine's
identity is recorded in the entry "instance root ID". The paper verifies this technique with an I/O side-channel 
exposed in /proc/stat, but no details were revealed (in the simplest form, just let one function write some data 
into the disk, and let the other check /proc/state for disk I/O. If the numbers are consistent with the amount of data 
written by I/O, then we can conclude that both instances are on the same physical machine. This is partially
due to the fact that containers, at the time of writing this paper, do not shadow the procfs for system statistics,
which allows containerized processes using this as a side-channel).

The first thing that the paper observes is that AWS Lambda will always assign function instances from different 
tenants, which correspond to different AWS accounts, to different VM instances. Multiple VM instances can be started
for the same tenant, but functions from different tenants will never be scheduled on the same VM for security and 
isolation. The paper also noted that exposing procfs of the hosting OS to each containerized process may seem harmless,
as only function instances from the same tenant can access them, this may actually turn into severe security threats
and isolation violation, if third-party service providers use AWS Lambda as their backend infrastructure, and creates 
functions on behalf of their users under the same AWS account (which is very likely). In this case, 
these function instances can share the same VM, while in the same time belonging to different logical tenants at the 
third-party provider's business logic. The paper conducted experiments on two real-world service providers, and 
confirms that achieving co-residency is trivial with only a few attempts on at least one of them.
The paper suggests that functions, even under the same AWS account, should be able to be assigned individual roles, and
be separated based on the fine-grained roles.

The paper then investigates into the instance create and placement algorithm on AWS Lambda. 
It is shown that instances are created for parallel requests up to 200 instances, which is the maximum observable 
number of concurrent instances. After that, requests are simply just queued and wait for a previous instance to 
complete. 
It is also shown that instances are also dispatched to the same VM instance to achieve high memory utilization, 
regardless of function types. The paper refers to this behavior as solving the "bin packing problem".
AWS Lambda allocates at most 3228 MB memory to a single VM instance, and requests are dispatched until the instance
run out of memory (Lambda functions are configured with memory requirements, so it is trivial to determine
whether a function instance will fit into the VM instance).

The paper measures cold start latency by sending two consecutive requests to the same function, with the first invoking 
the function with a cold start, and the second hitting a warm container process. 
Startup latency is measured as the time difference between the time the request is sent, and the time that the 
function starts execution (the second measurement is done and reported by the function as the first thing it does after 
being invoked).
The paper also identifies two cases of cold start. In the first case, both the VM instance and the container instance
is created, which will incur the maximum latency. In the second case, the VM instance is running, but the container
process still needs to be initialized. This will still incur moderate latency compared with a warm start.
Surprisingly, the paper finds out that the actual latency difference between the two cases is non-significant, and 
concludes that AWS Lambda pre-warms the VM instance in a pool of ready-to-launch VMs.
The paper also observes that due to the placement policy, the more parallel instances there are, the longer the latency
will be, which is a natural consequence of resource contention caused by co-locating all parallel instances into the 
same VM instance.

Container process lifetime is another interesting topic to investigate, since containers are transparent to functions,
while they can be recycled and kept alive by the infrastructure to serve later requests. 
The paper recognizes two types of container process lifetime. The first type is when the container is continuously hit
by requests, and the second type is when no request hits the container.
In the first case, the lifetime of containers are rather long, which can be as long as several hours.
In the second case, AWS Lambda will recycle containers in an exponential fashion: The infrastructure will terminate 
half of the existing containers of a certain function type for every 300 seconds, until there are two or three instances
left. After 27 minutes, all remaining instances of the type will be terminated as well.
This policy is enforced on a per-function type and per-VM basis.
The paper also observes that, any request that hits a container will reset the idle counter for all other 
containers running in the same VM. This is perhaps implemented from a spatial point of view: If one container
on a VM instance is hit, then it is likely that other co-located containers will also be hit. 

The paper discovers a possible implementation bug breaking the consistency of function code that gets executed after the
function is updated. The observation is that if the code of a function is updated, and requests are sent shortly
after that, it is still possible that the old version is executed. This is obviously caused by the infrastructure 
being unable to update all locally cached function copies atomically. The paper noted, however, that the window of 
vulnerability is quite small, since the abnormal behavior only lasts for a few seconds after the update.

In the last section, the paper delves into resource sharing and performance isolation. 
CPU time share is measured by having the function continuously calling fine-grained timestamp functions, and record 
the number of distinct time points in every 1000ms interval.
Results show that AWS Lambda allocates CPU time based on the memory size of the function. Larger functions will be 
allocated more fractions of the CPU time than smaller functions. As the number of instances increases on a single 
VM, the CPU share that each function is allocated also scales down proportionally.
As for disk and network I/O, the paper did not confirm or disprove whether they are allocated based on 
preconfigured memory size. Judging from the performance figure, however, it seems that maximum I/O throughout is still 
affected by the memory size, while network bandwidth is free of such constraints.
Similar to CPU cycles, as the number of co-located instances increase, the share that each of them can acquire also 
becomes smaller.
