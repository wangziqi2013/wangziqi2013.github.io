---
layout: paper-summary
title:  "Serverless Computation with OpenLambda"
date:   2021-10-02 04:25:00 -0500
categories: paper
paper_title: "Serverless Computation with OpenLambda"
paper_link: https://www.usenix.org/conference/hotcloud16/workshop-program/presentation/hendrickson
paper_keyword: Serverless; OpenLambda
paper_year: HotCloud 2016
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This workshop paper presents OpenLambda, an open-source framework (under development when the paper was published) 
that implements the serverless paradigm as an experimental platform for serverless innovations.
The authors of the paper identifies a few features that are critical for performance and usability of the platform, 
and briefly discusses them as potential point of interests that can be implemented in OpenLambda.

The paper begins with a discussion on the current commercial offering of serverless, namely, Amazon Lambda.
Generally speaking, Lambda is a serverless platform that allows individual functions to be uploaded by users, which
will also be individually scheduled anywhere on the cloud, triggered by external events. 
There are two major benefits of Lambda compared with conventional web applications. First, Lambda functions are 
written in high level languages, and the source file is typically small. It is therefore convenient to 
dispatch function code across the cloud, and then start execution with a language interpreter or JIT engine.
Second, no server-side management such as scaling configuration is needed, as these are already covered by the run 
time scheduler which scales out functions by starting more parallel instances to deal with dynamically changing 
workloads. In addition, high-level language functions are less affected by system level configuration differences 
such as library version or compiler compatibilities issues. The language infrastructure requires very little 
specification other than installing third-party packages. 

