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

