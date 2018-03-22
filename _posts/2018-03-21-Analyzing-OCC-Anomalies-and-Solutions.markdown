---
layout: post
title:  "Analyzing Optimistic Concurrency Control Anomalies and Solutions"
date:   2018-03-20 21:47:00 -0500
categories: article
ontop: true
---

### Introduction

Optimistic Concurrency Control (OCC) are gaining more and more attention as multicore
has become the mainstream platform for today's database management systems and transaction
processing systems. Compared with Two Phase Locking (2PL), OCC algorithms are expected to 
expose better degree of parallelism due to the wait-free read phase and relatively short 
validation and/or write phases that may require critical sections and/or fine grained locking.
One of the difficulties of designing efficient OCC algorithms, however, is to reason about complicated
read-write ordering issues due to the speculative and optimistic nature of OCC executions.
In this article, we discuss a few race conditions that are typical to OCC. For each race 
condition, we propose several solutions to avoid them. We also point out cases where OCC
may raise "false alarms" but are actually serializable. We hope our discussion could aid algorithm 
engineers to prevent common fallacies while still keeping the design efficient. 

### Racing Read and Write Phase

Race condition between read and write phases is the most common form of races in OCC. 