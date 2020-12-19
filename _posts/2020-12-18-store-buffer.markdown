---
layout: paper-summary
title:  "Boosting Store Buffer Efficiency with Store-Prefetch Bursts"
date:   2020-12-18 17:03:00 -0500
categories: paper
paper_title: "Boosting Store Buffer Efficiency with Store-Prefetch Bursts"
paper_link: https://www.microarch.org/micro53/papers/738300a568.pdf
paper_keyword: Microarchitecture; Store Buffer
paper_year: MICRO 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Lowlight:**

1. Isn't the last store address always the newest entry in the store buffer? I know it might be added just to keep
   the explanation easier, but I did not see why it can't be removed.

This paper proposes a store buffer prefetching scheme for handling store bursts. The paper observes that, on data 
intensive applications, the store buffer can incur a significant portion of pipeline stalls due to stores not being
drained in a timely manner. Previous proposals suggest that issuing cache coherence requests for prefetching can
reduce such effect on the pipeline, but still leaves much space for optimization. This paper, on the other hand,
employs a simple state machine to recognize common burst-write patterns, and issues prefetching requests even before
the store operation enters the store buffer. Compared with previous approcahes, this proposal requires less 
stringent timing between the prefetching and the actual access.

This paper assumes a common store-buffer based backend pipeline architecture. Store instructions (or uops) are issued
into the execution unit for address and source operand computation. The store operation can also be added into a 
dedicated structure, called the store queue, but this is irrelevant to the current topic.
When the store operation commits, it is inserted into another structure, called the store buffer (SB), which holds
store operations that have already committed and are potentially removed from the ROB (retired). Store operations are
drained from the SB in the order they are inserted (i.e., program order), but not ordered with any previous or future 
loads as well as non-memory instructions, observing the Total Store Ordering (TSO) model.

The SB can become the performance bottleneck for various reasons. First, the SB size is hard to scale as the core
frequency and other queue structures do, since the SB must be implemented as a fully-associative CAM to support 
store-load forwarding, with a complexity of O(n^2) where n is the number of entries. Second, with hyperthreading
enabled, the SB is evenly and statically divided between the two cores. This must be enforced, since otherwise
write-atomicity (the property that a logical thread can read its own writes early, while the store is only visible
to all other logical threads atomically at a future point) will be violated, causing consistency issues.

Since SB tracks store operations that have been committed, exclusive requests can be issued early as soon as these
operations enter the SB, without incurring cache pollution, since these addresses will definitely be written in the 
near future. Prior researches propose that the prefetching requests can be issued as soon as the store operation
finishes address generation (at-execute), or when the store operation commits (at-commit). 
This, however, still limits the performance gain from prefetching, since the window that prefetching must be completed 
is only between exectution or commit and the cycle when the store operation reaches SB head.

The paper observes that the SB can often become the performance bottleneck on data-intensive applications, where short
but intensive store bursts can occur as a result of memory copy, memory initialization, C++ standard template libraries,
etc. These store bursts are easy to predict and prefetch, since: (1) They access addresses with a regular pattern;
(2) They often occur in bursts within a short time window. The paper therefore utilizes this property, and proposes 
a simple predictor architecture for performing store prefetches.

The proposed architecture is as follows. Three more registers are added to the SB for prediction. The first register,
the last store address register, tracks the address of the last store operation. The second register, the saturated
counter register, is a 4-bit counter that tracks the status of the predictor. The last register, the store count
register, tracks the number of stores in the current access stride, which triggers prefetching when it reaches
a certain value.

When a store is inserted into the SB, the predictor checks the address as follows. If the address of the store
is to the next cache line or on the same line as recorded in the last store address register, then the saturating 
counter is incremented by one, and so does the store count register. Otherwise, all three registers are reset.
No matter what happened, the last store address register is always updated to the address of the store. 
