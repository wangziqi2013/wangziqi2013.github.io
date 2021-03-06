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
an iteration. The access iteration can be performing either speculative reads or writes. Write operation also requires a read, 
because typically the write is only a few words in length, and the rest of the cache line still needs to be read from a 
previous version. 

The creation timestamp and the in effect defines the "time range" of the cache line. Iterations below 
the range could not access it, because logically speaking, the cache line is created after the iteration has finished.
Iterations whose ID is in between the range could not write to the cache line, because the cache line has been read by
an iteration that logically execute after the current one. Attempting to write such a cache line will incur a write-after-read
violation. In the following discussion, we use (m, h) to represent the timestamp range of a cache line.

Each processor in the system is extended with an "Iteration ID", or VID, register. VID represents the logical ordering 
of an iteration, and defines the order of conflict resolution when a dependency occurs. The register is part of the processor
context, and needs to be saved and stored on context switches. Similar to dealing with floating point registers, this could 
be done lazily. The paper also proposes adding a few new instructions into the ISA. The *beginMTX* instruction 
loads the VID register with the ID of an iteration. Software is responsible for ordering iterations properly and assign
them VIDs. The *commitMTX*/*abortMTX* commits/aborts an iteration given the VID. Commits and aborts do not have to 
be on the same processor on which the iteration is started. The *initMTX* instruction saves a checkpoint of the execution 
context and sets the address of the recovery routine if the iteration aborts. 

The new protocol assumes a broadcasting bus and snooping protocol. Cache misses are handled by the cache controller via
a broadcast on the bus. Write operations are handled as a bus read without causing invalidation. The broadcasted packet 
is also piggybacked with the VID of the requesting processor. On receiving such a request, other processors check whether 
the request hits one of their cache lines using a set of modified visibility rules. If there is a hit, then the processor 
will reply as in an ordinary MOESI protocol. We next describe the operations of the new protocol in detail.

The S-M (m, h) state represents the most up-to-date version of a cache line. It is readable and writable by iterations whose VID 
is larger than h. Otherwise, a WAR violation is detected. Read operations from a remote processor hitting a line in S-M state 
will provide the remote processor with a cache line in S-S (m, h) state. On commit, S-M state represents the current version of 
a cache line, and will trasit to nonspeculative M state. VIDs greather than or equal to m will hit the line. Note that the 
access timestamp h is only used for violation detection, rather than visibility computing. 

The S-O (m, h) state represents an outdated cache line. There is a "newer" cache line created by a later iteration somewhere in 
the system. S-O lines are read-only, because writing a version that has already been superseded will cause a write-after-write (WAW)
violation. S-O lines are visible to requests whose VID is between the range. If an S-O line is requsted for read, the reading 
processor will obtain a copy in S-S state. On both commit and abort, S-O will be invalidated. S-O lines are created as a byproduct
of speculative writes. When a speculative write with VID z creates a new cache line in S-M state by writing into a cache line with
timestamp (x, y), an S-O line will be also created as the copy of the original line. The timestamp of the S-O line would be (x, z),
and the new line in S-M state will have timestamp (z, z). 

The S-E state represents a speculative state being read directly from non-speculative memory. Its creation timestamp is always zero.
The read timestamp defines the time range that this line is readable. If any iteration within the range attempts to write the line,
a WAR is detected, and the loop should be aborted. The visibility of an S-E line is not capped by its read timestamp. This is because
S-E lines are not versioned cache line. They are used merely to detect conflicts. The version is from the main memory, and should 
always be visible. If the line is to be overwritten, the S-E line transits to S-M while an S-O is also created as describes in 
previous paragraphs.

The S-S state represents a read-only copy of a cache line that was read from S-M, S-O and S-E lines. The timestamp of the S-S 
cache line is identical to the timestamp of the cache line from which it is copied. S-S lines are only visible to iterations whose
VID is within the range. S-S lines never respond to cache coherence events, because one of the S-M, S-O or S-E will respond.
Any attempt to write an S-S line will result in an immediate abort.

On commit, S-M and S-E lines will become M and E lines. S-O and S-S lines will be invalidated, because they either represent
obsolete data, or they are copied from an S-M/S-E/S-O line. On aborts, speculative states are thrown away while states originally
read from the main memory are restored. In this regard, S-E lines are restored to E states because that is where they were 
before the speculation. S-M and S-O lines become M lines, if their modification timestamp is zero, which indicates that they
are not written by speculative instructions, but by a non-speculative instruction before the loop starts. S-S lines always 
go into invalid state.

If the VID counter is about to overflow and wrap back, the runtime stops spawning new iterations. Instead, it waits 
for the last iteration to commit, and then broadcasts a VID reset signal to all processors in the system. The VID
reset signal will reset the creation and read timestamp for all cache lines in all processors to zero. The latter is 
optional in the design we described above, because the reset signal is sent after all iterations have committed. No
cache lines could have either timestamp be non-zero. If, however, the commit and abort optimization is used, the latter 
must be performed, because there can be speculative state lines in the system even if all iterations have committed.

In general, no speculative cache line can be evicted from the cache, which causes information loss. The cache controller 
should prioritize for speculative cache lines such that they are evicted after non-speculative lines. One exception, however,
is S-O lines whose creation timestamp is zero. They can be written back to memory safely. If a request of VID x hitting the 
evicted S-O line is broadcasted on the bus, and it hits nowhere, and in addition there is a S-M line on the same address,
then we know that the S-O line of creation timestamp zero must have been evicted. The line is read from the main memory
and assigned a timestamp range (0, x + 1). The cache controller could also take this into consideration, and prioritize 
accordingly when trying to evict speculative S-O lines with creation timestamp zero.