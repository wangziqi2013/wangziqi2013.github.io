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

**Comments:**

1. Is the IAT (inter-arrival time) computed at per-function basis, or per-application basis? I guess it has to be 
   per-function in order to make sense (because otherwise which function container you are going to warm up?).
   But the paper also mentions later that the policy applies at a per-application level.
   ** --> I think it is application level, because in a later paragraph the CV values are computed per application.
     In this case, how do you know which function to warm up next, if the predicted value only gives you the 
     interval but not function name? Did I miss something?**
   ** --> Most likely it is because Azure cloud hosts an entire application within a single container? So you only
      need to start the container for the application. This is mentioned in Section 2 of the paper as well.**

2. Typo in Section 3.4 second column, "50% of the functions have maximum execution time shorter than 3s". 
   I think it is 75%.

3. Likely a typo in Section 4.2, page 9, first column, "A histogram that has a single bin with a high count and all   
   others 0 would have a high CV". I think in this case the CV will be zero?
   **OK, it is not, this is to compute the CV of the height of the bars in the histogram, not the distribution
     of every data point (subtle difference). The former will result in small CV if all bars are equally high.**

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

This paper assumes the following serverless platform. Functions are grouped into applications, which is the basic unit
of scheduling and resource allocation. All functions in the same application are packed into the same container process,
with all the required libraries and runtimes, which will be started to handle requests to any of the functions.
Functions can be invoked by a few triggers, including HTTP requests, timers, and events generated by other cloud 
services. An application can have more than one triggers, which further complicates the task of predicting the timing 
of invocation requests.

In order to precisely predict function invocations to benefit function caching, the paper conducted several experiments
on a major serverless cloud platform, and makes the following observations regarding function invocation pattern
and resource consumption.
First, the most common triggers for invoking functions are HTTP requests, which is followed by timers as the second 
common trigger. Although timer invocations are
easy to predict as their deadlines are explicitly known to the scheduler, the paper noted that a large fraction of 
functions either do not use timer, or they combine timer with other kinds of triggers, which is more difficult to 
predict. It is hence implied that the primitive policy of waiting for timers to fire will not work well. 

Second, the invocation frequency varies significantly between functions and applications, with the difference being
over eight orders of magnitude. Besides, less than 20% of the functions constitute more than 99% of total function
invocations. Both facts suggest that the fixed keep-alive latency does not work well in general, as keeping those
infrequently called functions alive will just waste resource.

The paper also computes the coefficient of variation (CV) of the length of intervals (inter-arrival time, IAT) 
between two consecutive requests
of an application. Results show that certain applications have a CV of zero, indicating very a tight distribution, 
which, as the paper explains, might be from IoT devices that report status periodically.
On the other hand, most applications do not observe any particular probability distribution, and the CV values also
vary greatly across applications. This result suggests that some application's IAT is easy to compute as they have 
a regular pattern, while others are non-trivial.
Idle time, the interval between two invocations of the same function, follows a similar pattern as IAT, which is
measured at application level. 

Lastly, the paper measures the execution time and memory consumption of each function, and concludes that functions 
are typically small, with most of them being within 60 seconds, and 50% of them completes within one second. 
This further emphasizes the importance of reducing cold start latency, since the cold start overhead is relatively
large given the short function execution time.
Memory usage varies by 4 times for most applications, suggesting that the caching overhead would be high, if the 
policy is designed poorly.

