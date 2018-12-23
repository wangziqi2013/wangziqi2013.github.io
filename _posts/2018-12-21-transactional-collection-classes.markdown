---
layout: paper-summary
title:  "Transactional Collection Classes"
date:   2018-12-21 18:25:00 -0500
categories: paper
paper_title: "Transactional Collection Classes"
paper_link: https://dl.acm.org/citation.cfm?id=1229441
paper_keyword: Concurrency Control; MVCC; OCC; Interval-Based CC
paper_year: PPoPP 2007
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes semantic concurrency control, a technique that reduces transactional conflicts on data structures when
they are wrapped in long transactions. With transactional memory, it is temping to implement data structure operations using 
transactions. When the data structure is used in larger transactions for extra atomicity (e.g. multiple operations on the 
data structure are expected to complete as an atomic unit), then it is inevitable that the transaction used to implement 
data structure operations will be nested with the parent transaction. Depending on the design of the transactional memory, three
nested models are generally available: First, nested transactions can be flattened, and hence become part of the parent 
transaction. The read and write set of the child transaction will be merged with the parent's. If the nested transaction 
needs to abort, then the entire parent will also be rolled back. The second model is called closed nesting, where the 
read and write sets of the child transaction is maintained separately, and it is possible that only the child transaction
is rolled back on a conflict. Dirty results of the child transaction can only be observed by other transactions after the 
parent commits. Compared with flattened transaction, closed nesting can reduce the number of wasted cycles
when only the child transaction encounters a conflict but not the parent. After the child transaction commits, conflict 
detection will still be performed for the committed child transaction, as the read and write sets of the child transaction
are merged into its parent. The last model is open nesting. Compared with closed nexting, open nesting transactions
expose their dirty values immediately after they commit. Reads and writes of the child transaction do not cause aborts
after it commits. If the parent transaction aborts, an abort handler must be executed which rolls back the committed
child transaction explicitly. Isolation is not maintained for open nested transactions, and without extra mechanism to 
enforce data accesses, open nested transactions may not satisfy serializability.

Semantic concurrency control tries to deliver the best of both closed nesting and open nesting: Instead of merging the 
read and write sets of the child transaction into the parent's, they can be diacarded as soon as the child 
transaction commits. This reduces the chance that the child transaction physically conflicts with concurrent transactions 
that access the data structure. On the other hand, accesses to the data structure are restricted by semantic locks. 
If an access is not compatible with an existing committed operation, then one of these two operations have to be aborted.
Compared with previous approaches, by using semantic locks, transactions on the data structure only conflict on 
logical operations. Physical conflicts are tolerated, as long as (1) The consistency of the data structure is preserved,
i.e. these operations still need to be atomic with regard to each other, but they are not necessarily atomic in the 
context of the parent transaction; (2) The semantics of the operations do not conflict. One example is the semantics of 
an integer set. Adding a member into the set does not conflict with membership query as long as the key of these two
operations are distinct. On the physical implementation level, however, these two operations might conflict just
because they modify the same counter, linked list node, etc. If we reduce the goal of concurrency control down to simply 
avoiding logical conflicts, while preserving the consistency of the data structure, less aborts will be observed, which
reduces both the number of wasted cycles, and increases concurrency.

The details of the algorithm are described as follows. Before we apply semantic concurrency control to data structures, we 
must first figure out which operations would conflict on each other on which conditions. As shown in the above example
on integer sets, addition of an element will conflict with membership query of the same key, element removal of the same key 
and size query in all cases. After figuring out conflicting patterns between operations, we add semantic locks to
the data structure. Semantic locks are acquired by reading transactions on the data structure before they commit.
When a parent transaction accesses the data structure via some operations, depending on the operation type, two different 
things can happen. If the operation is read-only, then it is executed as an open nested transaction. Before the transaction
commits, it acquires semantic locks that indicate incompatible operations. Note that transactions are stilled used 
to guarantee isolation of operations as well as consistency of the data structure. It is just that after the open nested
transaction commits, the parent will not be aborted by later operations on the data structure, because conflicts are 
now detected based on semantic locks, rather than the memory access pattern. If the read-only transaction fails, the parent
does not need to roll back. Instead, only the read-only child transaction is retried, since it is read-only and always 
idempotent. If, on the other hand, the operation is read-write, it is executed within a sandbox, i.e. all modifications 
to global data will be redirected to a transactional-local buffer used as a software store queue. If reads from the 
same transaction hits the store queue, then these accesses will also be redirected to the buffer. On transaction commit,
conflict resolution is performed by applying these changes in the store queue back to the data structure using a 
commit handler. It is described as follows. First, the commit handler checks whether any conflicting locks is being held
by uncommitted reading transactions. In the set example, if a read-only transaction queries for key x = 100, and the writing
transaction inserts 100, then the semantic lock for key = 100 is acquired by the former. When the latter commits,
the commit handler should be able to discover that the lock is being held by the former, and hence detects a conflict.
In this paper, conflicts are detected and resolved using Forward OCC (FOCC). Either the commit handler aborts the 
writing transaction, or the reader fails and retry after the writer commits. Let us assume that the reading transaction
is aborted (and the parnt rolls back to the point where the nested reading transaction is invoked), the commit handler
then proceeds to commit all changes in the store queue back to the data structure. This write back sequence must also be 
wrapped in a transaction to avoid creating inconsistencies in the data structure, since there can be concurrent 
operations running on the data structure as well at the same moment. If the commit transaction fails because of 
low level physical accesses conflict, it can simply be just retried without rolling back the parent. After transaction commits
or aborts, the store queue and locks are both released.