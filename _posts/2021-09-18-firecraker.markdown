---
layout: paper-summary
title:  "Firecracker: Lightweight Virtualization for Serverless Applications"
date:   2021-09-18 20:47:00 -0500
categories: paper
paper_title: "Firecracker: Lightweight Virtualization for Serverless Applications"
paper_link: https://www.usenix.org/conference/nsdi20/presentation/agache
paper_keyword: Virtual Machine; Serverless; Lambda
paper_year: NSDI 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
--- 

This paper presents Firecracker, a lightweight VMM platform designed and optimized specifically for serverless. 
This paper contains little technical discussion, especially on the implementations of the Firecracker VMM (it is 
open-sourced, though), and it focuses more on the high-level ideas that motivate the design principals of 
Firecrackers, and how it is deployed in a production system. 
Nevertheless, being able to see an industrial system that has already been tested under production environments 
is always beneficial, and the insights provided by this paper may server as a guideline for future system designers 
working on serverless and other related topics.

Firecracker is motivated by the intrinsic trade-off between isolation and efficiency for general-purpose virtualization
solutions. On one side of the spectrum, containers leverages namespaces, control groups, secure computing 
(seccomp-bpf), and special file systems to allow multiple processes to have their own view of the system, while 
physically they are still sharing the same underlying kernel. 
