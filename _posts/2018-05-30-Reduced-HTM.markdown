---
layout: paper-summary
title: "Reduced hardware transactions: a new approach to hybrid transactional memory"
date: 2018-05-30 13:05:00 -0500
categories: paper
paper_title: "Reduced hardware transactions: a new approach to hybrid transactional memory"
paper_link: https://dl.acm.org/citation.cfm?id=2486159.2486188
paper_keyword: Reduced HTM; Hybrid TM; TL2; RH1; RH2
paper_year: SPAA 2013
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Hybrid transactional memory can provide the efficiency and parallelism of hardware transactional 
memory by executing the majority of transactions via the hardware path, while maintain the flexibility
of software transactional memory when hardware fails to commit using the slower software based path.
The interoperability between HTM and STM transactions is achieved by designing the algorithm
in a way that both HTM and STM transactions would notify each other of possible conflicts. One
prominent example is Hardware Lock Elision (HLE), where HTM transactions and STM transactions cooperate
to execute a critical section. In HLE, when the hardware executes a lock acquisition instruction, HTM transactions 
speculatively verify that the lock is clear, adding the lock into its read set, and then execute the critical section. 
Any attempts by software fall-back transactions to acquire the lock will abort hardware transactions immediately. 
Multiple hardware transactions can execute in parallel given no data conflict, while the execution of 
HTM and STM transactions must be serialized. HLE may suffer from low degrees of parallelism in some workloads, 
because the serialization of HTM and STM transactions is unnecessary in many cases. This, however, should not
be a major problem, as the majority of transactions in HLE are expected to be executed in hardware mode. 
Only transactions that consistently fail (e.g. because the working sets exceed hardware capacity) will 
use the fall-back path. The latter is relatively infrequent.

In the near future, we may possibly only use HTM for smaller transactions whose size is stable and predictable. 
In the long run, however, the size of transactions executed with HLE might become more heterogenous than 
ever, featuring a mixture of small and large transactions. If this is the case, then the classical method for 
HLE will be overly restrictive, as HTM may observe frequent aborts by STM transactions. To reduce the negative effect
of "subscribing" to the lock early at the beginning of HTM transactions, HLE algorithms may adopt "lazy subscription", 
in which the lock is only subscribed by HTM transactions before commit. Hybrid NORec is one of the several 
hybrid transactional memory designs that makes use of lazy subscription. The advantage of lazy subscription is that
hardware and software transactions can commit in parallel if they access independent set of data items. The drawback,
as can be shown by another paper, is that hardware transaction may read inconsistent states in the middle of an
STM commit. This is impossible for early subscription, since any software commit will trigger the hardware transaction
to abort. We observed that such inconsistent execution will eventually be detected when the STM commit phase completes 
writing back all dirty items. To solve the inconsistent read problem, hardware load instructions must be instrumented 
to run a validation routine after the load is performed. The validation routine spins on the lock and waits for the 
currently committing STM transaction, if any, to complete. 

The hardware instrumentation of load instructions can affect performance in a yet unknown manner. To alleviate the 
problem of performance degradation caused by instrumentation, this paper proposes two hybrid transactional memory 
algorithms based on TL2. The first algorithm, RH1 (RH stands for "Reduced Hardware Transaction"), consists of a full
hardware path and a hardware-assisted fall-back path. RH1 makes non-trivial assumption about the underlying HTM 
implementation, and is still "best-effort". The second algorithm, RH2, consists of a hardware assisted fast path and
a pure software slow path. It also provides a "middle ground" for the hardware path to cooperate with the software 
path if both types of transactions are executing in parallel. Both RH1 and RH2 fast path avoids expensive load instrumentation, 
and are expected to perform better than Hybrid NORec with lazy subscription.

The base algorithm of RH1 and RH2 is based on TL2, a state-of-the-art STM design. TL2 is essentially an MV-OCC algorithm.
The general form MV-OCC algorithm has a global timestamp counter. Transactions read the conter before they start as the 
begin timestamp (bt). The value of bt fixed a read snapshot for the transaction. Any change of the snapshot that overlaps 
with the read set of the transaction will cause an abort. On transactional read, either dirty values are forwarded from the 
wrire set, or the read operations go to data items whose write timestamp is smaller than or equal to bt (if the version
does not exist then abort). On transactional write, the dirty value is buffered in a local write set. On transaction commit,
items in the write sets are locked to guarantee atomic write back phase. Then the read set is validated. If validation
succeeds, the timestamp counter is atomically incremented, the after value of which is used as the commit timestamp (ct) of 
the transaction. During the last write back phase, all dirty values in the write set are written back with their versions set
to ct, and then unlocked. TL2 differs from the general MV-OCC described above in several aspects. First, TL2 is not multiversioned.
Only one version, i.e. the most recently written version, is maintained. If a transaction tries to read a value whose version is 
greater than the current bt (which implies that the version in its snapshot no longer exists), then the transaction aborts.
Next, there is a contention between transaction write back and read phase. Imagine that if a new transaction begins after the 
timestamp counter is incremented but before the write back completes. The new transaction may read partial committed states,
and still passes validation, because the committed value has a ct equal to the bt of the new transaction. The simplest approach is to
prevent new transactions from beginning when a commit in in-progress (as in Stanford SI-TM). TL2 attacks the problem differently.
Instead of lowering the potential parallelism by disallowing concurrent commit and acquisition of bt, TL2 takes advantage of an
observation: a data item is potentially in an inconsistent state only if it is locked. When reading a data item, TL2 samples 
the version lock before the read operation, then performs read, and samples the version lock again. It will abort if one of the 
following three check fails: (1) The lock in the second sample is held; (2) The versions differ in two samples; and (3) The versions are 
larger than the begin timestamp. (1) ensures that the read did not take place when a lock is being held, i.e. the read itself 
is consistent if the operation consists of multiple non-atomic loads; (2) ensures that no write back of the value takes place 
between the two samples; (3) ensures no write back takes place after the bt is acquired. Together, they ensure that all unlock
operations happened between transaction begin and the second sampling are with a smaller or equal transaction ID. In this case,
the read operation serializes the current transaction after the committing transaction by reading their values.

The RH1 algorithm extends TL2 by executing at least the entire write phase as an atomic transaction. The hardware path
executes all phases as a single hardware transaction, and the software path executes the validation and write phase as 
a single hardware transaction. Write locking is unnecessary in both cases, because write operations from different transactions 
will never interleave. The hardware path executes load instructions without instrumentation. Store instructions are instrumented 
such that the version of a data item is also updated speculatively. No begin timestamp is obtained at transaction begin, because
any write operation to data items after it was read will trigger an abort. Note that in TL2, any write operation afther the 
transaction has begun is disallowed. In contrast, RH1 allows transactions to commit before the data item is actually read. 
The commit timestamp is obtained at begin time using the Global Value library. The implementation of the global counter guarantees 
that the increment operation does not cause concurrent transactions to abort.