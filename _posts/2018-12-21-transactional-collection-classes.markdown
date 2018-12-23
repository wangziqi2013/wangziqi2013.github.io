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
If an access is not compatible with the 