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
Back to the 90's, most database management systems use Strict Two-Phase Locking (S2PL) as the stabndard implementation
of serializability. In S2PL, transactions acquire locks on data items before they are accessed. Locks are only released 
at the end of the transaction (commit or abort), blocking accesses from other transactions entirely.