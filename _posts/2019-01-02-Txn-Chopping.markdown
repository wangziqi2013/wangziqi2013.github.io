---
layout: paper-summary
title:  "Simple Rational Guidance for Chopping Up Transactions"
date:   2019-01-02 21:35:00 -0500
categories: paper
paper_title: "Simple Rational Guidance for Chopping Up Transactions"
paper_link: https://dl.acm.org/citation.cfm?id=130328
paper_keyword: Transaction Chopping; Relaxed Concurrency Control
paper_year: SIGMOD 1992
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes transaction chopping, a technique for reducing transaction conflicts and increasing parallelism.
Back to the 90's, most database management systems use Strict Two-Phase Locking (S2PL) as the standard implementation
of serializability. In S2PL, transactions acquire locks on data items before they are accessed. Locks are only released 
at the end of the transaction (commit or abort), blocking accesses from other transactions entirely. Transactions
are serialized by the point they acquire all locks. 

For some transactions, S2PL may be too restrictive to achieve serializability. For example, assume that there is an 
online shopping website which runs a backend with only one type of transaction, the purchasing transaction, which consists 
of two operations. The first operation is to deduct the amount of money from a user's account balance, which involves a 
read-modify-write operation. The second operation is to add the amount of value to a per-user counter, which stores 
the total amount of money the user has spent. To prevent users from buying when their account balance is insufficient,
the transaction also checks whether the balance is larger than or equal to the value of the item before purchasing. 
At any given moment, the same user can have multiple instances of the purchasing transaction running on the backend. 
The invarinat we want to preserve is that users should never be able to buy if their account balance is insufficient
to pay for the item. In this scenario, S2PL is definitely sufficient to make the execution serializable, because the account
balance is locked after the transaction checks it, and hence no other transaction could access the value. It is, 
however, also possible that serializability is still guaranteed, but we execute the purchasing transaction in two 
smaller transactions: In the first transaction, user's balance is checked against the value of the item. The first 
transaction aborts immediately if the user has insufficient balance. Otherwise, the first transaction deducts the amount 
from the account balance, and then commits. The second transaction is only executed if the first transaction commits. 
In the second transaction, the amount of money is simply added onto the total amount of value, and then the transaction 
commits. Both transactions use S2PL as their concurrency control algorithms, which requires no change to the database 
design. Programmers just split one transaction into two, and instruct the database to conditionally execute the second one. 
The reasoning showing that chopping the purchasing transaction into two pirces will not break serializability is as follows:
if two transactions, let's call them A and B, violates the invariant that user's balance must not be negative, then
it must be that these two transactions both committed when the account balance is less than the sum of the two items 
bought. In this case, both transaction must commit the first piece, in which the balance is checked and adjusted. 
Recall the assumption that the first piece is executed as a transaction. We know there can only be two
interleavings for the first piece: Either A's piece is executed first and B's second, or the opposite of it. In neither 
case should the account balance become negative, as the check is always performed, and if the account has insufficient 
balance, the piece will abort. A contradiction!

More formally speaking, transaction chopping seeks a way to force locks to be dropped before the transaction can acquire
extra locks on data items, hence breaking the S2PL rule. In the previous example, the transaction is chopped in a way such
that the lock on account balance is dropped before the lock on total amount is acquired. Relaxing the S2PL rule helps 
increasing parallelism of the system, because locks are held for shorter durations of time. As a result, less transactions 
will be blocked due to lock conflicts, and even if they do, the time they spent waiting for the lock is also shorter. 
Note that unlike some relaxed 2PL proposals which explicitly changes the locking protocol and modifies the database system, 
transaction chopping is a technique which leaves the database intact, and only seeks to re-write transactions under certain 
conditions to obtain extra free parallelism. It is therefore easier to deploy transaction chopping compared with 
previous approaches, because no fundamental change to the system needs to be done. 

Transaction chopping must be done following a certain set of rules. The most crucial goal is that serializability must
be maintained. To achieve this goal, the paper proposes using SC-graph to determine whether a given chopping of 
a transaction is legal (i.e. satisfies serializability). The SC-graph is constructed as follows. Given transaction
T<sub>1</sub>, T<sub>2</sub>, ..., T<sub>n</sub>, and their corresponding chopping c<sub>11</sub>, c<sub>12</sub>, ...,
c<sub>21</sub>, ..., c<sub>nk</sub>, we treat each piece c<sub>ij</sub>, as a node. We connect nodes with two 
types of edges