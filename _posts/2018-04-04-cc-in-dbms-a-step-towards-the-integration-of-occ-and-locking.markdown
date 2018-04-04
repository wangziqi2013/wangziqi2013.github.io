---
layout: paper-summary
title:  "Concurrency Control in Database Systems: A Step Towards the Integration of Optimistic Methods and Locking"
date:   2018-04-04 16:17:00 -0500
categories: paper
paper_title: "Concurrency Control in Database Systems: A Step Towards the Integration of Optimistic Methods and Locking"
paper_link: https://dl.acm.org/citation.cfm?id=809759
paper_keyword: OCC; 2PL
paper_year: 1981
rw_set: Set
htm_cd: Both Eager and Lazy
htm_cr: Both Eager and Lazy
version_mgmt: Both Eager and Lazy
---

This paper proposes a concurrency control manager that uses OCC and 2PL. 
The motivation for the integrated approach is based on observations as follows.
Two-Phase Locking (2PL) guarantees progress of transactions in the absence of deadlock,
but suffers from high locking overhead especially for small transactions.
On the contrary, classical OCC with backward validation (BOCC) has low locking overhead, but
the chances that transactions are forced to abort in validation phase increases for long 
transactions, as more write sets of committed transactions are tested for non-empty
intersection. If conflicts occur frequently, long transactions can never commit,
causing the starvation problem.

