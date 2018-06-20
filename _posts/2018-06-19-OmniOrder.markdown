---
layout: paper-summary
title:  "OmniOrder: Directory-Based Conflict Serialization of Transactions"
date:   2018-06-19 22:55:00 -0500
categories: paper
paper_title: "OmniOrder: Directory-Based Conflict Serialization of Transactions"
paper_link: https://ieeexplore.ieee.org/document/6853223/
paper_keyword: HTM; OmniOrder; Sequential Consistency
paper_year: ISCA 2014
rw_set: On-chip buffer
htm_cd: Eager
htm_cr: Eager
version_mgmt: Eager (Uncommitted Read)
---

Conflict-based Hardware Transactional Memory (HTM) suffers from high abort rates when conflicts are frequent.
This is caused by the simple conflict detection mechanism which treats any cache coherence message that hits 
transactional cache lines as potential sources of violation. The only exception to this rule is bus read shared 
request on shared or exclusive lines, as reader processor cannot conflict with other readers. Processors 
will abort and restart if a conflict is detected, discarding any speculative states from its private cache, 
because there is zero information for tracking how the cache line will be used by another processor. This 
property is sub-optimal, because not all dependencies imply violations at the end of the execution.

This paper proposes OmniOrder, an HTM extension on existing commercial HTM such as Intel TSX to support more 
efficient dependency reasoning. Instead of keeping zero information about global usage of a cache line, processors 
are extended with a few structures that can track the modification history as well as dependencies of 
speculatively modified cache lines. One of the highlights in the design of OmniOrder is its native support for 
unmodified directory-based cache coherence protocol. This feature is crucial for a practical HTM design, for two
reasons. First, directory based protocol is a must in today's high performance architecture. Inability to 
support directory based protocol is a huge deficiency. In contrast, some HTM designs require broadcast 
cache coherence protocol, which makes the design non-scalable and impossible to port to large scale systems.
Second, unmodified coherence protocol implies only incremental change is needed on existing microarchitecture.
Designing and verifying a correct coherence protocol is difficult. What makes it worse is that the actual 
number of state in the state machine is far more than the steady states. Transient states that handle
race conditions must be added to ensure multiple operations can be performed in parallel. All these factors 
discourage the invention of a new coherence protocol. In the next paragraph we cover in detail the hardware 
changes required to implement OmniOrder.




