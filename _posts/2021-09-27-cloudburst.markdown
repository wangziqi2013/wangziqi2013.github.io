---
layout: paper-summary
title:  "Cloudburst: Stateful Function-as-a-Service"
date:   2021-09-27 01:16:00 -0500
categories: paper
paper_title: "Cloudburst: Stateful Function-as-a-Service"
paper_link: https://dl.acm.org/doi/10.14778/3407790.3407836
paper_keyword: Serverless; CloudBurst; Key-Value Store
paper_year: VLDB 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents Cloudburst, a serverless framework that allows functions to preserve states between invocations
by using a distributed key-value store with strong consistency guarantees.
This paper is motivated by the fact that today's serverless frameworks only provide stateless functions, which disallows
communication between functions for the ease of scaling and management. 
Cloudburst addresses the limitation with a global key-value store serving as the persistent state storage across 
function invocations, combined with a per-instance cache for low-latency access.
Cloudburst also implements a distributed consistency model that enables concurrent accesses of shared states by 
different functions, which also turns the key-value store into a fast communication channel.
