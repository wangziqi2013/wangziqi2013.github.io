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
types of edges. S edges, or "sibling" edges, connects all pieces from the same transaction. Essentially, every two
pairs of pieces from the same transaction are connected by an S edge. C edges, or "conflict" edges, connects pieces 
from different transactions. If two pieces from different transactions access the same data item, and at least one 
of them is a write, then we connect these two pieces using a C edge.
Note that both S and C edges are bi-directional. This is because we are only performing static analysis, and hence 
we can only draw possibilities of conflicts, but do not know the actual direction of conflicts until run time.
In a high level, S edges identifies all pieces in the same transaction, which is necessary for identifying 
conflict cycles, because conflicts (and the notion of seriazability) are only meaningful for transactions. 
C edges identifies actual conflicts that can potentially happen during the execution. Since pieces are executed
themselves as atomic units, if transaction A has two or more distinct pieces (call them p1, p2) that conflict with 
a piece of transaction B (call it p3), then it is possible that p3 is executed between p1 and p2, and that 
transaction A is serialized both before and after B, causing a conflict cycle. A more detailed analysis can also be 
performed for scenario with more than two transactions and more than three pieces (by induction). The conclusion is 
that, in order for a chopping to be serializable, there must not be any cycle in the SC-graph where at least one 
C edge and one S edge is in the graph.

Two more observations follow the above conclusion on SC-graph. First, given a chopping whose corresponding SC-graph has 
at least one SC-cycle, any further finer division of this chopping must also have at least one SC-graph. We show this by induction.
In the base case, no further chopping is done, and the graph has at least one cycle. Assume that after some chopping steps
the graph still has one or more cycles. Then what if we chop a piece into two in the next step? There are two possibilities.
In the first case, a piece that does not constitute any cycle is chopped. This does not change existing cycles, and hence 
the resulting graph must have at least one cycle. In the second case, we chop a piece that constitute a SC-graph. We assume 
w.l.o.g. that the piece is p1 and it is connected with p2 and p3. Chopping p1 into p11 and p12 does not break the cycle
because p11 and p12 are connected by an S-edge, while p11 and p12 themselves are connected with other nodes via the 
original edges. By induction, we know that no matter how we further chop an already invalid chopping, the resulting 
chopping remains invalid. The second observation is that, if a given chopping has an SC-cycle that involves two or more
pieces of Ti (i.e. two or more pieces of Ti, pi1 and pi2, constitute the cycle), then if we merge all chopped nodes for all transactions 
execpt Ti, there would still be an SC-cycle. We prove this by induction by showing that the cycle will not disappear no
matter how we merge pieces. In the base case, no pieces are merged, and the observation is trivially true. In the induction step,
assume that some pieces have already been merged, and there is still an SC-cycle. In the next step we select two pieces 
to merge (note: not all pieces are merge-able, but it is guaranteed that we can always find some pieces to merge as long
as the transaction has not been fully merged). If none of these pieces is within the cycle then the cycle is not affected. 
Otherwise, there are three possibilities. First, none of the pieces has a C-edge. In this case the cycle still holds because 
only one S-edge disappears, and since pi1 and pi2 has an S-edge that could not be removed, the SC-graph always has at least
one C-edge and one S-edge. In the second case, one of the two pieces has a C-edge. In the third case, both pieces have 
C-edges. In both cases, the number of C-edges is not affected, because merging pieces only affect the number of S-edges.
Using a similar argument in case one, we know that there is still an SC-cycle no matter how we merge pieces. 

The first observation helps us identify when to stop chopping. It is easily shown that the chopping should stop when
the split of any piece will induce a cycle, because further steps of chopping will not make the cycle disappear. The
second observation helps us degisn an algorithm to perform chopping. It shows that it makes no difference when we chop
transaction Ti, whether or not the other transactions have been chopped. This is because SC-graphs do not disappear
if we split or merge pieces in transactions other than Ti. 

Taking advantage of the above two observations and their derivations, we can design an algorithm that chops transactions 
using only local knowledge. The algorithm only considers one transaction at a time, without knowing the exact chopping of 
other transactions, thanks to observation two above. Note that in a database system, usually multiple instances of the same
transaction will be running at the same time. If this is true, then during the chopping of transaction Ti, the other 
"reference transactions" must also all transactions in the system, including Ti, because it is possible that one instance 
of Ti conflicts with another instance. The algorithm runs in a bottom-up manner described as follows: First, transaction 
Ti is chopped such that each read/write operation is an individual piece. We do not chop any other transaction, and consider
them as an entire piece. Then, the SC-graph between Ti pieces and other transactions are drawn. In the next stage, the 
algorithm merges pieces of Ti such that no cycle can exist. The merge process runs iteratively. The algorithm searchs 
connected components between Ti pieces and other transactions in which at least two pieces in Ti are involved. For each 
of the connected component found, all pieces in Ti are merged (if they are merge-able), such that no S-edge exist. The 
merging step erases all SC-cycles, because there is no S-edge (if there is one then that is a connected component). The 
algorhtm terminates if no such components can be found. The same process is run for every transaction without using 
existing choppings of transactions that have already been processed. It is proved in the paper that the chopping is 
actually optimal in a sense that no further chopping can be done, while the execution of chopped transactions 
can still achieve seriazability given that each transaction is protected by S2PL.