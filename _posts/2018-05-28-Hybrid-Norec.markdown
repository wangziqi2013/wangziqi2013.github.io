---
layout: paper-summary
title: "Hybrid NOrec: a case study in the effectiveness of best effort hardware transactional memory"
date:   2018-05-28 17:19:00 -0500
categories: paper
paper_title: "Hybrid NOrec: a case study in the effectiveness of best effort hardware transactional memory"
paper_link: https://dl.acm.org/citation.cfm?doid=1961296.1950373
paper_keyword: NORec; STM; Hybrid TM
paper_year: ASPLOS 2011
rw_set: Hybrid
htm_cd: Hybrid
htm_cr: Hybrid
version_mgmt: Hybrid
---

Current implementations of commercial hardware transactional memory (HTM) features lazy
version management and eager conflict detection. A transactional store instruction cannot be 
observed by both transactional and non-transactional loads until the writing transaction
commits. In addition, both transactional and non-transactional store to a location in 
a transaction's read set will cause an immediate abort of that reader transaction. Since 
transactions are not guaranteed to complete successfully, such HTM implementations is called
"best-effort" HTM.

NORec, a lightweight software transactional memory (STM) design, features lazy version management
and incremental lazy conflict detection. A transactional write to data items cannot be observed by 
other STMs until the writing transaction commits. This, however, will cause a hardware transaction
to abort. NORec always maintains a consistent read set by using a commit counter. The commit 
counter serves three purposes. First, it acts as a global write lock to all data items, serializing
the write phase of all committing transactions. Second, the commit counter also signals all 
reading transactions that a commit has taken place/is being processed. The read set of the 
transaction should be validated using value validation when the commit operation finishes. 
This is achieved by transactions taking a snapshot of the commit counter before it starts and 
before every validation. If the value of the commit counter differs from the snapshot after a 
load operation or after a validation, the load or validation must be retried. This ensures that
all read and validation are conducted under a consistent snapshot where no transaction has ever 
committed. The last purpose of the commit counter is to indicate an "unstable" state of the snapshot,
and hence prevent new transactions from beginning. New transactions take a snapshot of the counter,
and if a commit is currently going on, the new transaction will not begin.

The commit counter in NORec is a 64 bit integer consisting of two parts. The lowest bit of the integer 
serves as the "locked" bit. If it is set, then a commit is currently being processed. All remaining bits 
comprise the version counter, which counts the number of commits (excluding the current one if the lowest
bit is set) that have taken place. Committing transactions first set the lock bit to exclude all other 
transactions from committing, performing reads, validating, and beginning. Then it writes back the write 
set. After the write back completes, it clears the locked bit and increments the version counter by one.
The last step is performed using atomic Fetch-and-Add or Compare-and-Swap. In fact, the assignment of bits in 
the commit counter allows both atomic "lock" and "unlock-increment" be carried out by an atomic Fetch-and-Add 
by one.

The simplest way of integrating NORec and best-effort HTM is stated as follows. The STM runs without modification.
For HTM, we instrument the transaction begin and commit logic to let hardware transaction (1) wait for software 
transaction to finish before it starts, i.e. hardware transaction could not begin when a software write back is 
being processed; and (2) The STM must be informed if a hardware transaction commits, such that the STM could have 
a chance to validate its read set. (3) The HTM must also be informed if the STM writes onto its read set. Enforcing (1)
requires the HTM instrumentation to add the commit counter into its read set, and spin on that counter until 
the lock bit is cleared. (2) requires the HTM to increment the commit counter by two and also add it into the write set,
before it executes the commit instruction. (3) does not need any special handling, because before the STM commits,
the commit counter will be incremented by one to set the lock bit, which will trigger an immediate HTM abort.

The invariant we try to maintain in the hybrid approach is that all commit phases must be serialized. No interleaved 
writes is acceptable. In the above scheme, HTM could not commit inside an STM commit phase, because neither could HTM
begin when STM is currently committing, nor could STM commit without aborting the HTM. If the STM commits while an HTM
transaction is running, then the increment of the commit counter will force the HTM transaction to abort.

Having HTM transactions incrementing the counter can be overly restrictive. Due to the fact that HTM transactions all 
have the counter in their read sets, incrementing the counter atomically by either STM or HTM will abort all HTM transactions.
This is necessary for STM to notify HTM that a STM transaction is being committed, to prevent the HTM committing on the 
read set of the STM transaction after it validates successfully. This "subscription" mechanism is unnecessary between
HTM transactions, as they guarantee serializability using the cache coherence protocol. Having HTM transactions aborting 
each other via the commit counter restricts the degree of parallelism, because HTM transactions are forced to not 
overlap their execution phases with any commit instruction. In an improved scheme, each core in the system is allocated a 
local counter, which is incremented by a committing transaction running on that core as part of the transaction write set. 
HTM transactions still "subscribe" from the commit counter at the beginning of the transaction to get notifications of 
STM commits. The difference is that now the STM validation process should validate all HTM counters by value, using the value 
validation technique as it does for data items as well. This way, STM transactions serialize with each other using 
lazy versioning, non-atomic write back and incremental conflict detection, while HTM transactions serialize with each 
other using lazy versioning, atomic write back and eager conflict detection. HTM and STM transactions synchronize 
with each other using the STM commit counter and HTM local counters. STM proactively notifies HTM of its commit to abort
all executing HTM, no matter true data conflict happens or not. HTM signals STM about its commits using the local 
commit counter. STM is responsible for making sure that if either STM or HTM changes the counter, it will perform 
a value validation.

As can be easily seen from the previous description, if the HTM transaction subscribes to an STM transaction by 
reading the commit counter, then the HTM transaction is forced to abort whenever an STM transaction commits. The 
abort does not take into consideration the actual data conflict. One might try to optimize this by using 
"lazy subscription", i.e. the HTM thread only subscribes to the commit counter right before it executes the 
commit instruction. The subscription of commit counter synchronizes with the atomic Fetch-and-Add increment in 
NORec commit protocol. The serialization order of STM and HTM transactions is determined by the order that they
reach the respective synchronization point. Several changes must be made to ensure correct serialization between 
STM and HTM transactions. The first change, of course, is that HTM transaction begin no longer reads the commit counter.
The second change makes transaction pre-commit read the commit counter, and spin on it until the lock bit is clear.
This spin operation adds the value of the counter in the read set, and serializes the HTM and STM write phase. 
If an STM transaction attempts to commit by incrementing the commit counter, the HTM transaction will abort.
The third change adds validation for every load instructions. Such instrumentation is indispensable, because the 
HTM transaction can begin when a STM is performing write back, and also STM commit does not cause HTM to abort.
It is therefore possible that the HTM reads partial committed state of a STM by performing reads in the middle 
of the write back phase, and reads half-committed, half-uncommitted data that will be committed later. Fortunately, 
such partial state read will eventually abort the HTM transaction, after the completion of the STM write back phase. 
On every load instruction, the HTM should validate simply by waiting for the current write back phase, if any, to 
complete. This is achieved by spinning on the commit counter until its lock bit becomes clear.