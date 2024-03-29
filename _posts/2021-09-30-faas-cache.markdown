---
layout: paper-summary
title:  "FaaSCache: Keeping Serverless Computing Alive with Greedy-Dual Caching"
date:   2021-09-30 21:04:00 -0500
categories: paper
paper_title: "FaaSCache: Keeping Serverless Computing Alive with Greedy-Dual Caching"
paper_link: https://dl.acm.org/doi/10.1145/3445814.3446757
paper_keyword: Serverless; FaaSCache; Caching Policy; Greedy-Dual Caching
paper_year: ASPLOS 2021
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. Function keep-alive can be modeled as a caching problem, and many principles of caching applies.
   Function instances can be thought of as variable-sized objects, with the amount of free memory as the cache size, 
   cold start latency as miss penalty, warm start latency as hit latency, function size as object size, 
   and function invocation frequency as the access frequency.

2. The function cache also needs to be dynamically resized to maintain a stable hit ratio. This is consistent with
   the serverless paradigm in which functions can be easily scaled up.
   Cache size is determined given a target hit ratio by running simulations with either analytics or just cache
   simulation.
   The cache size is adjusted in the run time by comparing the dynamic hit ratio with the target ratio, and add or 
   remove memory to the cache based on the result of comparison.

**Comments:**

1. I do not quite get why you need per-instance clock? If all instances of the same type are using the same amount of
   resource, then evicting any of them would be the same. Why bother distinguishing between instances with the 
   per-instance clock? Shouldn't per-type clock suffices?
   Maybe cache locality is also taken into consideration here, e.g., the policy favors the instances that are recently
   used because it is likely that part of its working set is still in the LLC and thus it runs faster?

2. Why maintain the per-worker node "clock" counter as eviction counter, rather than access counter? 
   Wouldn't the latter be more intuitive, because it is then equivalent to the LRU recency counter?
   Using eviction does not really count the recency, because instances accessed between two evictions will have
   the same clock value.

3. I also do not get why you need to over-provision? Isn't the best thing about serverless is that you do not 
   over-provision, and just start new instances anywhere on the cloud (i.e., easy scale up)? 
   **OK, they are talking about over-provisioning of the cache storage. But this term is misleading, because it is
   just dynamically changing cache size based on workloads**

This paper presents FaaSCache, a caching policy for virtual machine keep-alive in multi-tenant environments containing
heterogeneous function instances. The paper is motivated by the fact that commercial cloud providers nowadays all
cache function instances on the worker node to alleviate the long cold start latency, which is incurred by the 
initialization cost of the container itself and the language runtime. The caching strategy, however, has not been 
well-studied, leading to simple but sub-optimal design decisions such as the naive expiration mechanism.
This paper draws an analogy between the function caching problem with a more traditional and broadly studied problem 
of caching variable sized objects, and proposes better policies for function caching and VM over-provisioning.

FaaSCache is built upon the concept of function keep-alive, which has now become a standard practice for cloud 
providers to not terminate the container or VMM instance (we use the term "container" below to refer to both)
after the function completes. Cloud providers keep function instances alive for two reasons.
First, containers themselves incur the overhead of booting a system (for VMM), or setting up the isolated environment
(for containers). Second, the language runtime is also likely to take time to initialize, including downloading and 
importing library dependencies. 
By keeping the container instance alive after execution, and hosting the same function the next time a request arrives,
the so-called cold start overhead can be avoided, and functions generally will have shorter latency from being
requested to being completed, which is a desired feature as serverless functions are typically small.

The paper points out, however, that function keep-alive is not free lunch. The trade-off between performance and 
resource utilization must be paid by keeping container instances in the main memory, as the resource allocated to
those containers, mostly memory resources, are not reclaimed. 
It is, therefore, a crucial part of serverless services to be able to balance between performance and utilization
with smart keep-alive policies.
Existing commercial solutions are rather simple, which just keeps warm instances in the main memory for a fixed period
of time before they are deemed as unlikely to be reused in the future and then destroyed.
The paper argues that the simple policy does not always provide optimal result, and that it is challenging to 
design a effective policy for two reasons.
First, function containers are not identical. They consume different amount of resources, require different setup
times, and are requested at different frequencies. The simple policy obviously does not take any of these into 
consideration, and a more comprehensive policy should cover all the factors that may affect the effectiveness of 
function keep-alive.
Second, serverless functions are often scaled based on the dynamic workload, which requires a change of resource
allocated to the function. The amount of resource reserved for function keep-live, in the meantime, should also
change in order to better accommodate the incoming traffic. The simple policy, for example, is unable to determine 
the optimal number of warm instances per function type to keep alive. This paper proposes a mechanism, known as 
Elastic Dynamic Scaling, to properly scale the resource allocated to a single function type for an optimal "hit rate" 
of the warm containers.

One of the most critical observation made in the paper is that function keep-alive is essentially a caching problem.
If the total amount of resource (this paper mainly focuses on memory resource as it is the major cost of keeping
function containers warm) is considered as the capacity of the cache, then the cold and warm start latencies are 
analogous to the cache miss and hit overheads, respectively.
Additionally, requests to invoke functions are just accesses to the cache, and each function type has a different
frequency of access, indicating its popularity.
The intuition here is that the caching policy should favor functions with smaller memory footprints, larger cold
start overheads, and are requested more frequently. 
There is, however, one major difference between function keep-alive and caching, which is the fact that multiple 
instances of the same function can co-exist on the same worker node, while some of the traits mentioned above, such
as the access frequency of a certain function type, are shared by all instances of the same type
(counting per-instance access frequency is nonsense, because the scheduler will randomly choose an instance to
satisfy the request).
As a contract, in the classical caching problem, every cached object is considered as distinct, and they do not
share any traits. 
This little inconsistency, in fact, affected the design of the policy such that both per-instance and per-type traits
are considered when making eviction decisions.

We next discuss the operational details of FaaSCache. All resources allocated to serverless are considered as usable
cache storage by FaaSCache, and the framework always attempts to fill the cache as long as resource permits. 
When a request arrives, the framework will select a cached container instance of the requested function type, and 
dispatch the request to one of the free instances. If such an instance cannot be found, then one or more existing free 
instance must be evicted just like in a regular cache to free up the resource for the new instance.
The eviction is based on a per-instance priority value computed given all the factors discussed above, plus a 
"clock" value indicating the last time the instance is used (i.e., the "recency" of the instance as in LRU).
The priority is computed as (clock + (frequency * cost) / (size)), in which frequency, cost, and size corresponds to
the access frequency, the cold start latency, and the memory consumption of the function type as we discussed above.
The clock is a per-worker node counter, which is incremented for every eviction, and is assigned to an instance when 
a request is dispatched on it.
Frequency, cost, and size are all per-type traits, and they can be measured by maintaining a statistics for each
function type cached on the node. The cold start latency is measured as the difference between a cold start and 
a warm start. The measurement is performed only once when a new function type is first time cached and first time
accessed after being cached.
On eviction, the priority value of all instances are computed and sorted, and then the lowest priority instances
are evicted, until the resource is sufficient for starting the newly requested instance.

FaaSCache also implements Elastic Dynamic Scaling, a mechanism for adjusting the cache size dynamically in the
run time based on the workload. 
Elastic Dynamic Scaling consists of two components. The first component statically computes the initial cache size
using a profiling trace aiming at a certain hit ratio, and the second component dynamically adjusts the cache size
based on the target hit ratio and the run time dynamic ratio.
The static ratio is computed from a trace of function requests by simulating a cache of given size.
The cache simulation can either be done by enumerating each reasonable size and running simulation with the given size,
or analytically with reuse distance defined as the amount of memory that is needed by caching other functions between 
two consecutive invocations of the same function.
The paper also notes that this process is expensive, but is only performed once at initialization stage.
During the execution, the actual hit ratio of the function cache is periodically compared with the target ratio. 
If the former is lower, indicating that there is not sufficient number of instances to satisfy requests from cache, 
the cache size will be increased by a certain amount, such that more function instances can be accommodated and 
that the chances that a free instance can be found on a function request increases. 
