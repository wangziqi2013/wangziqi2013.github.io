---
layout: paper-summary
title:  "Serverless in the Wild: Characterizing and Optimizing the Serverless Workload at a Large Cloud Provider"
date:   2021-10-08 18:11:00 -0500
categories: paper
paper_title: "Serverless in the Wild: Characterizing and Optimizing the Serverless Workload at a Large Cloud Provider"
paper_link: https://www.usenix.org/conference/atc20/presentation/shahrad
paper_keyword: Serverless; Azure; Caching Policy
paper_year: USENIX ATC 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents serverless workload characteristics on Microsoft Azure cloud environment, and proposes a 
hybrid, histogram-based caching policy for reducing cold starts.
The paper is motivated by the performance-memory trade-off of pre-warming and caching the execution environment of 
serverless functions, which effectively reduces the occurrences of cold starts, at the cost of extra resource 
consumption. 
The paper investigates several crucial factors that may affect the trade-off, such as function invocation
pattern, execution time, and memory usage, and concludes that caching would be effective and necessary in order for the
platform to perform well. 
The paper then proposes a hybrid caching policy that leverages either observed pattern histograms, or time series
data, to compute the warm-up and keep-alive time, which is later shown to be able to reduce both resource consumption
of caching and the invocation latency.

The paper begins by identifying the cold start latency issue on today's serverless platform, which is caused by the 
initialization overhead of the virtualization environment (we use the term "container" and "container process" to 
refer to this in the rest of this summary, despite that the environment can also be a virtual machine instance) 
as well as the execution environment that needs to be set up for every execution. Due to the fact that serverless 
functions are relatively small, these added latency can 
become more significant than in a conventional cloud setting where services would run for a long period of time
after being invoked.
The paper also observes that cold starts are more common during workload spikes, at which time the scheduler will try to
scale up the application by starting more function instances, hence introducing more cold starts.

Existing serverless platforms address the cold start issue with function keep-alive. Instead of shutting down a 
container process right after the function completes, the environment will be kept in the main memory of the 
worker node for a fixed amount of time (typically tens of minutes), such that if the same function is requested, 
the same container can be reused to handle the function, which eliminates the cold start latency.
The paper argues that, however, such practice is sub-optimal for two reasons.
First, these warm container processes continue to consume memory but does not do any useful work, which wastes system
resources. Second, users are also aware of the simple caching mechanism, and will attempt to monopolize the 
container process by deliberately sending dummy "heartbeat" requests periodically, further exacerbating the resource
waste.

Obviously, a better policy that does more than fixed time keep-alive is needed. The paper identifies two important
goals of the new policy. First, policies should be able to be enforced at a per-application level, because the 
invocation patterns and other criteria differ greatly from application to application. Second, the policy should 
also support pre-warming of containers, such that even if requests arrive relatively infrequently, which makes 
keep-alive less economical, cold start latency can still be avoided by starting the container right before the 
request arrives.
