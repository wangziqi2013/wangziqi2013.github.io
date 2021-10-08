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
initialization overhead of the virtualization environment as well as the execution environment that needs to be set
up for every execution. Due to the fact that serverless functions are relatively small, these added latency can 
become more significant than in a conventional cloud setting where services would run for a long period of time
after being invoked.
The paper also observes that cold starts are more common during workload spikes, at which time the scheduler will try to
scale up the application by starting more function instances, hence introducing more cold starts.

