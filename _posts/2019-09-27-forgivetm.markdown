---
layout: paper-summary
title:  "ForgiveTM: Supporting Lazy Conflict Detection on Eager Hardware Transactional Memory"
date:   2019-09-27 00:14:00 -0500
categories: paper
paper_title: "ForgiveTM: Supporting Lazy Conflict Detection on Eager Hardware Transactional Memory"
paper_link: N/A
paper_keyword: HTM; Conflict Detection
paper_year: PACT 2019
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes ForgiveTM, a bounded HTM design that features lower abort rate than commercial HTMs. ForgiveTM 
reduces conflict aborts by leveraging the observation that the order of reads and writes within a transaction is 
irrelevant to the order that they are issued to the shared cache, as long as these reads and writes are committed atomically 
and that the coherence protocol provides most up-to-date lines for each request. The paper also idientifies that currently 
available commercial HTMs are all eager due to the fact that Two-Phase Locking (2PL) style eager conflict detection maps 
perfectly to the coherence protocol. For example, a read-shared (GETS) request us equivalent to a read-only lock in 2PL,
while a read-exclusive request is equivalent to writer lock. During the execution, the cache controller monitors speculatively
accessed cache lines during the transaction, and sets the corresponding bit. When a conflicting request is received
from another core, the current transaction must be aborted to avoid violating the isolation propeerty. Past designs also
propose lazy conclift detection, which allows transactions to proceed after conflicts are detected, and only resolve these
conflicts at the time of commit (or abort if the transaction risks accessing inconsistent data). The lazy approach to
conflict detection, however, as pointed out by the paper, often requires modifications to the coherence protocol, which
is hard to design and verify, or assumes certain hardware structures that are difficult to implement (e.g. ordered 
broadcasting network). Lazy conflict detection usually provides better performance and lower abort rates for three reasons. 
First, the "vulnerabilty window", during which the transaction's reads and writes are exposed to other transactions, is smaller 
with lazy detection schemes. In contrast, eager schemes expose reads and writes as coherence states once they are performed
on the cache, and any coherence request will result in an abort. Second, under lazy scheme, transactions can determine the 
serialization order at a later time, e.g. when they are about to commit, rather than always serializing before the current 
owner transaction of the cache line by forcing the latter to abort. This adds extra flexibility to the protocol and allows
more read/write interleavings to commit. The last reason is that lazy conflict detection avoids certain pathologies in which
transactions abort each other without making any progress due to the fact that transactions started later always attempt
to serialize before the transaction that started earlier on a conflict. On a balanced system in which transactions are 
of similar sizes, however, those started earlier should be given higher priorities to commit, since they are expected to 
have a larger working set, and aborting these transactions will waste more cycles. 

ForgiveTM combines eager and lazy schemes by only exposing certain writes, while leaving the rest in a private per-transactional 
table until commit or the table overflows. ForgiveTM assumes a baseline system similar to Intel TSX, and only adds incremental
changes to the architecture without modifying the coherence protocol at all. In the baseline system, each cache line is 
extended with a "T" bit, which indicates whether the cache line has been speculatively accessed by the processor. Loads
and stores issued within the transaction will set the "T" bit in the cache after acquiring the cache line. To ensure that
transactions can be rolled back, when a dirty, non-speculative cache line is accessed, the dirty content is first written
back into lower level caches before that line can be updated. The "T" bit is cleared on both commits and aborts, and in
the case of an abort, the valid bit is also cleared. Pre-transaction data can be fetched from lower level caches after 
such an abort. ForgiveTM does not attempt to extend the baseline system to support unbounded transactions. In the case of a
speculative state overflow, the transaction is aborted.

ForgiveTM extends the cache controller hardware to recognize cache lines that should be exposed lazily, which is described 
as follows. First, cache lines are extended with an "L" bit, which indicates that stores to the line should be exposed lazily.
If this bit is set, stores to this line will ignore the coherence state, and will directly update the line content (since
it is assumed that proper permissions have been acquired). In addition, ForgiveTM adds a table which records the tags
of lines with the "L" bit set. A new tag will be added to the table when the line is to be modified by a store instruction
if the table still has an empty slot. We postpone the discussion of table overflow to later paragraphs. The last change made
by ForgiveTM is a predictor which gives hint on whether a cache line should be exposed lazily or not based on the number of 
aborts incurred by that line. The predictor is used to reduce the amount of storage required to store all lazily acquired
lines.

