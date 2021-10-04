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

