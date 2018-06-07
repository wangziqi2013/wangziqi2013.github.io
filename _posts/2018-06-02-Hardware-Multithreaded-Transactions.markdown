---
layout: paper-summary
title:  "Hardware Multithreaded Transactions"
date:   2018-06-02 03:16:00 -0500
categories: paper
paper_title: "Hardware Multithreaded Transactions"
paper_link: https://dl.acm.org/citation.cfm?id=3173172
paper_keyword: Thread Level Speculation; MOESI; Coherence; HMTX
paper_year: ASPLOS 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---   

This paper proposes a cache coherence protocol for thread-level data speculation (TLDS).
The paper assumes a pipelined programming paradigm, where two threads, the producer and the consumer,
cooperate to finish a loop. The producer thread iterates through all stages of the loop and produces 
the context of the loop. For example, if the loop traverses a linked list and invokes a processing function 
for every node in the linked list, the producer thread will perform the iteration without invoking the processing function. 
Instead, it speculatively writes the pointer to the current node into a local variable, and then continues with the next node. 
Since speculative writes are private only to the iteration that produces, later on when the consumer thread begins
on the context, it could find the pointer to the node in the same local variable. One or more consumer threads 
then process the nodes in parallel by entering the corresponding iteration context first, and then invoking the 
processing function.

The goal of the new protocol is to achieve the following during the speculation. First, cache lines created by 
different iterations should be maintained separately and privately. They should be able to co-exist with each other 
even inside the same set of a cache. Second, threads should be able to enter and exit an iteration without causing 
the current speculation to commit or abort. The previously mentioned producer-consumer paradigm relies on this feature 
to allow producers to set up the iteration context first, and then consumers to finish the iteration. Third, control logics, 
especially cache hit/miss and commit/abort logic, must be local. Determining whether a request hits a cache line should not 
involve any global coordination or search, unlike in some protocols where a request could "possibly hit" a cache line.

With these design objectives in mind, the paper extends the widely deployed MOESI cache coherence protocol by adding 
speculative states of the non-speculative counterparts. The addition of speculatively states should satisfy two 
different goals. First, these speculative states should preserve the state of the cache line before it is accessed 
speculatively. Once an iteration commits or aborts, the speculative cache line should return to a correct non-speculative 
state. Second, the speculative cache lines add new semantics to cache coherence, allowing iterations to perform private 
writes and pass dirty states to each other without incurring ordering violations. Four new states are added: Speculative 
Modified (S-M), Speculative Owned (S-O), Speculative Shared (S-S) and Speculative Exclusive (S-E). Besides, each cache 
line also have two more fields in their tags. The first field is the creation timestamp. When an iteration performs a 
speculative write, and creates a new version of the cache line, the iteration ID of itself is written into the field.
This field is used to determine whether a cache line is visible to a particular request. We describe the concrete protocol
in later sections. The second field is the last accessed timestamp. It is updated when the cache line is accessed by
an iteration. The access iteration can be prforming either speculative reads or writes. Write operations also needs a read, 
because typically the write is only a few words in length, and the rest of the cache line still needs to be read from a 
previous version. The creation timestamp and the in effect defines the "time range" of the cache line. Iterations below 
the range could not access it because logically speaking the cache line is created after the iteration has finished.
Iterations whose ID is in between the range could not write to the cache line, because there is a later 