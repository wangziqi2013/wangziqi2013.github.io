---
layout: paper-summary
title:  "Concurrent Certifications by Intervals of Timestamps in Distributed Database Systems"
date:   2018-04-07 21:39:00 -0500
categories: paper
paper_title: "Concurrent Certifications by Intervals of Timestamps in Distributed Database Systems"
paper_link: http://ieeexplore.ieee.org/document/1702233/
paper_keyword: OCC; FOCC; Dynamic Timestamp Allocation
paper_year: 1983
rw_set: Set
htm_cd: Lazy 
htm_cr: Lazy
version_mgmt: Lazy
---

This paper proposes a new OCC algorithm that computes the commit timestamp (ct) in a distributed way.
Classical OCC algorithms like set-intersection based and version-based OCC all require a total ordering
between transactions, which is determined by the order that they finish the write phase. In this scheme,
timestamps are allocated by atomically incrementing a centralized global timestamp counter. As the 
number of processors and distances between processors and memory modules increase, the centralized
counter will become a major bottleneck and harms scalability. Furthermore, read operations determine
their relative order with committed transactions in order to detect overlapping read and write phases.
This is usually achieved by reading the global timestamp counter as the begin timestamp (bt) without 
incrementing it at the beginning of the read phase. The validation routine compares the most up-to-date 
timestamp of data items with the bt. If bt is smaller, then the validating transaction aborts, because a
write has occurred between bt is obtained and the start of validation. 