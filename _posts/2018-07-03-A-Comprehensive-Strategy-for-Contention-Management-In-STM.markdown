---
layout: paper-summary
title:  "A Comprehensive Strategy for Contention Management in Software Transactional Memory"
date:   2018-07-03 21:12:00 -0500
categories: paper
paper_title: "A Comprehensive Strategy for Contention Management in Software Transactional Memory"
paper_link: https://dl.acm.org/citation.cfm?id=1504199
paper_keyword: STM; TL2; Contention Management
paper_year: PPoPP 2009
rw_set: Lock Table for Read; Hash Table with Vector for Write
htm_cd: Lazy
htm_cr: Lazy
version_mgmt: Hybrid
---

This paper proposes a contention management system that supports Software Transactional Memory with lazy acquire
and lazy version management. The system features not only a generally better contention management strategy, but
also enhances the base line STM with useful capabilities such as programmer-specified priority, irrevocable transaction,
conditional waiting, automatic priority elevation, and so on. 

Contention management is important for both eager and lazy STM designs. The goal of a contention management system is 
to avoid pathologies such as livelock and starvation, while maintaining low overhead and high throughput. Past researches
have mainly focused on policies of resolving conflicts when they are detected during any phase of execution. Among them, the 
Passive policy simply aborts the transaction that cannot proceed due to a locked item or incompatible timestamp; The 
Polite policy, on the other hand, commands transactions to spin for a while before they eventually abort the competitor,
which allows some conflicts to resolve themselves naturally; The Karma policy tracks the number of objects a transaction
has accessed before the conflict, and the one with fewer objects is aborted. This strategy minimizes wasted work locally.
The last is called Greedy, which features both visible read and early conflict detection. Transactions are also assigned
begin times. The transaction with earlier begin time is favored. Also note that due to the adoption of visible reads, the 
Greedy strategy incurs some overhead even if contention does not exist.

None of the above four contention management strategies works particularly well for all workloads and for all STM 
designs. In the paper the baseline is assumed to be a TL2 style, lazy conflict detection and lazy version management
STM. Each transaction is assigned a begin timestamp (bt) from a global timestamp counter before the first operation.
The begin timestamp determines the snapshot that the transaction is able to access, and is also used for validation.
Transactions are assigned commit timetamp (ct) from the same global counter using atomic fetch-and-increment after
a successful validation. Each data item has a write timestamp (wt) that stores the ct of the most recent transaction 
that has written to it, and a lock bit. The wt and the lock bit can be optionally stored together in a machine word. 
On transactional read operation, the wt of the data item is sampled before and after the data item itself is read. 
The read is considered as consistent if the versions in the two samples agree, and none of them is being locked. 
If this is not the case, then the transaction simply aborts, because an on-going commit will overwrite/has already 
overwritten the data item, making the snapshot at bt inconsistent. If the data item is in the write set, then the
read returns the updated item instead of performing a global read. On transactional write operation, the dirty value
is buffered at a local write set. The implementation of the write set can affect performance, as we shall discuss later.
On transaction commit, the protocol first locks all data items in the write set. If a lock has already been acquired 
by another transaction, then the current transaction will abort. Then validation proceeds by comparing the current wt
of data items in the write set with the bt. If any of them is greater than bt, then a violation has occurred, and 
transaction aborts. Otherwise, the ct is obtained, and dirty values in the write set are written back. Data items
are unlocked at the end of the transaction.

The original TL2 algorithm described above suffers from several prformance problems. The first problem is read 
forwarding, which happens when a dirty data item is read. The semantics of most STMs require that the read operation 
must return the dirty value. Since TL2 maintains versions in the write set lazily, the write log must be searched 
sequentially on *every* read operation (after optionally checking a bloom filter), which is both costly and pollutes 
the cache. This paper proposes using a hash table in addition to a linear log. The log can be traversed linearly
as usual during commit and write back, while the hash table provides shortcuts into the middle of the list to
accelerate item lookup. Note that the same problem does not exist in STMs using eager version management, because
the data item is updated in-place, and the metadata of the item is designed such that the owner of the item can be 
easily inferred.

The second problem that leads to sub-optimal performance is spurious aborts. The dual timestamp scheme fixes the 
snapshot as the global state at bt, and tries to extend the snapshot to transaction commit at ct. The entire speculative
execution is based on the assumption that the snapshot at time bt will not change until ct, which suggests that any commit 
operation on the read set from bt to ct will trigger an abort. This, however, is overly restrictive, because what 
the speculative execution really needs is just a consistent snapshot, regardless of time. For example, let us assume a 
transaction starts at time bt, another transaction commits on data item X at (bt + 3), and then the transaction reads 
X in the read phase. According to the original TL2 algorithm, the transaction should abort as soon as it sees the wt
of X. This abort, however, can be avoided, if the transaction validates its past reads to see if they are still valid 
at (bt + 3). In the majority of cases, the validation should pass, which means that if the past reads are performed using
a begin timestamp equals (bt + 3), they should still observe exactly the same value. In the extensible timestamp design,
the transactin will then promote its begin timestamp to (bt + 3). If validation fails, then the transaction aborts,
because the snapshot is no longer valid at time (bt + 3). 