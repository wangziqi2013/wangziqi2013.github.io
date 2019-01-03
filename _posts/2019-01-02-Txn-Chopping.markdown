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
the transaction also checks whether the balance is larger than or equal to the value of the good before purchasing. 