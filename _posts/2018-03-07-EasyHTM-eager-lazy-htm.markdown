---
layout: paper-summary
title:  "EazyHTM: Eager-Lazy Hardware Transactional Memory"
date:   2018-03-07 22:37:00 -0500
categories: paper
paper_title: "EazyHTM: Eager-Lazy Hardware Transactional Memory"
paper_link: https://timharris.uk/papers/2009-micro.pdf
paper_keyword: EazyHTM; Decoupled conflict resolution and detection
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
delays conflict processing till commit point, allowing better degree of parallelism. On the other hand, however, the commit process 
will be unnecessarily slowed down if conflicts are detected via a validation phase before commit, because conflicts themselves were 
already known when they took place during the processing phase. 

To minimize wasted work while keeping the commit protocol simple, EazyHTM adopts eager CD but postpones CR till commit point. It assumes
a directory based cache coherent system. The observation is that speculative stores during txns can be treated in the same way as load 
operations, only causing a shared state to be marked in the directory. For transactional load and store requests (txMark), the 
directory marks the requestor as a sharer, and sends it back the number of other sharers of the requested cache line. 
The directory also notifies all other sharers that an incoming transactional operation is pending (txAcc). On receiving a txAcc message,
a sharer will respond directly to the requestor about the transactional operation it has performed on the specified cache line. The 
requestor, in the meantime, waits for the response from each sharers (it knows the exact number of sharers from the directory), 
and if any sharer has performed a conflicting operation, the requestor will add it to a "conflicting list". 
As the last step, upon receiving the reply from a sharer, the requestor also sends back its operation to
the sharer. The sharer adds the requestor to a "killer list" if their operations conflict.

Although not mentioned in the paper, both transactional and non-transactional loads can only be fulfilled from DRAM or shared cache, 
instead of other processor's private cache. Otherwise, the txn's dirty data may be propagated, causing the undesirable effect called 
"dirty read".

When a processor is about to commit, it first locks its read/write set to avoid establishing new dependencies while invalidating
conflicting txns. All transactional load/store notifications (i.e. txAccess) are replied with txTryLater. Then, for each
conflicting procrssors in its conflicting list, the processor sends an abort message, and wait for the acknowledgement. On
the other side, if a processor receives an abort message, it first checks whether the sender is in its killer list. If not,
then the abort message is simply ignored. This check is to ensure that we do not abort txns that just happen to run on the
same processor but does not have any conflict with the committing txn. If the committing txn receives acknowledgements
from all conflicting txns, it is logically committed, and the processor moves to the next stage.

After finshing the first stage of commit, an invariant is guaranteed that no processor can have a speculatively modified/read copy of 
any of the cache lines in the committing txn's write set, and no processor can have a speculatively modified copy of 
any of the cache lines in the committing txn's read set. This is bacause before the read/write set is locked, all txns
that have a cache line in a conflicting state must have been detected and recorded in the conflicting list, and thus 
are aborted with cache line invalidated. After the read/write set is locked, no new dependencies can be established.

On the second stage of commit, the committing txn requests exclusive ownership for every cache line in its write set, in
the exact way that a non-transactional store operation would do. It then writes its speculative changes back to the 
main memory, and finishes the commit process. After commit finishes, the read/write set can be unlocked (i.e. allow new 
dependency to be established).

The second stage of commit can be optimized by allowing other processors to transactionally access a cache line even before 
it has finished write back, i.e. we unlock the read/write set of the committing txn after the first stage early. This early 
release of read/write sets will not harm correctness, as long as we write back the requested line before responding to the 
requestor that the requested line is a non-transactional line.

EazyHTM only applies to transactions whose working sets do not overflow the cache. The paper claimed, although, that it is 
not difficult to virtualize the txn and to make them unbounded, no concrete solution or even hint is given.

Why it works
------------

Lazy conflict resolution (postponing read validation till commit time) sometimes has the problem of inconsistent read
or non-repeatable read, even if we pair it with lazy version management. This is because under read-committed semantics,
a reader txn could still read inconsistent values during the commit process of a writer. This phenomenon, however, is
not possible in EazyHTM. Consider the three execution stage of a writer txn: read, validate, write. During read stage, 
all speculative written cache lines are not made public, and hence are not observable by other readers. Then, during the 
validation stage, the writer txn validates its write set by acquiring exclusive ownership. Reader txns that have 
read the (old value) of cache lines in the writer's write set, realize that a writer txn will WB on this line upon seeing, 
the broadcasted invalidation, and therefore aborts. At this moment, no cache line is written, and the reader also could not observe 
inconsistent state. During the WB stage, the write set itself is locked, such that no new conflicts can be 
established by readers trying to read a line in the writer's write set, until WB finishes. This way, 
it is guaranteed that reader txns never see the temporary inconsistent state created by the WB stage.

