---
layout: paper-summary
title:  "EazyHTM: Eager-Lazy Hardware Transactional Memory"
date:   2018-03-07 22:37:00 -0500
categories: paper
paper_title: "EazyHTM: Eager-Lazy Hardware Transactional Memory"
paper_link: https://timharris.uk/papers/2009-micro.pdf
paper_keyword: Conflict resolution; Directory based coherence; 2 Phase Commit
paper_year: 2009
rw_set: L1 Cache
htm_cd: Eager
htm_cr: Lazy
version_mgmt: Lazy
---

This paper proposes a restricted HTM design, EazyHTM (EArly + laZY) that decouples conflict detection (CD) from conflict resolution (CR). 
While prior designs usually do not distinguish between CD and CR, and use either early or late for both, EazyHTM detects conflicts early, 
but delays the resolution to commit time. This scheme addresses one of the problems of early conflict resolution, where
one txn aborts another txn, and then itself is later aborted, resulting in wasted work. This can be avoided if the hardware 
delays conflict processing till commit time, allowing better degree of parallelism. On the other hand, however, the commit process 
will be unnecessarily slowed down if conflicts are detected via a validation phase before commit, because conflicts themselves were 
already known when they took place during the processing phase. 

To minimize wasted work while keeping the commit protocol simple, EazyHTM adopts eager CD but postpones CR till commit point. It assumes
a directory based cache coherent system. The observation is that speculative stores during txns can be treated in the same way as load 
operations, only causing a shared state to be marked in the directory. For transactional load and store requests (txMark), the 
directory marks the requestor as a sharer, and sends it back the number of other sharers of the requested cache line. 
The directory also notifies all other sharers that an incoming transactional operation is pending (txAcc). On receiving an txAcc message,
a sharer will respond directly to the requestor about the transactional operation it has performed on the specified cache line. The 
requestor, in the meantile, waits for responses from other sharers (it knows the exact number of sharers from the directory), 
and if any sharer has performed a conflicting operation, the requestor will add it to a "conflicting list". 
As the last step, upon receiving the reply from a sharer, the requestor also sends back its operation to
the sharer. The sharer needs to add the requestor to a "killer list" if their operations conflict.

Although not mentioned in the paper, both transactional and non-transactional loads can only read from memory, other than
from other processor's cache. Otherwise, the txn's dirty data may be propagated, causing the undesired effect called "dirty read".

When a processor is about to commit, it first locks its read/write set to avoid forming new dependencies while invalidating
conflicting txns. All transactional load/store notifications (i.e. txAccess) are replied with txTryLater. Then, for each
conflicting procrssors in its conflicting list, the processor sends an abort message, and wait for the acknowledgement. On
the other side, if a processor receives an abort message, it first checks whether the sender is in its killer list. If not,
then the abort message is simply ignored. This check is to ensure that we do not abort txns that just happen to run on the
same processor but does not have any conflict with the committing txn. If the committing txn receives knowledgements
from all conflicting txns, it moves to the next stage, and is logically committed.

After the first stage of commit, we guarantee the invariant that no processor can have a speculatively modified/read copy of 
any of the cache lines in the committing txn's write set, and no processor can have a speculatively modified copy of 
any of the cache lines in the committing txn's read set. This is bacause before the read/write set is locked, all txns
that have a cache line in a conflicting state must have been detected and recorded in the conflicting list, and are 
therefore aborted with cache line invalidated. After the read/write set is locked, no new dependencies can be established.

Then, on the second stage, the committing txn requests exclusive ownership for every cache line in its write set, in
the exact way that a non-transactional store operation would do. It then writes its speculative changes back to the 
main memory, and finishes the commit process. After commit finishes, the read/write set can be unlocked (i.e. allow new 
dependency to be established).

The second stage of commit can be optimized by allowing other processors to transactionally access a cache line even before 
it has finished write back, i.e. we unlock the read/write set of the committing txn after the first stage early. This early 
release of read/write sets will not harm correctness, as long as we write back the requested line before responding to the 
requestor that the requested line is a non-transactional line.