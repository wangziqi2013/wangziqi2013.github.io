---
layout: paper-summary
title:  "ForgiveTM: Supporting Lazy Conflict Detection on Eager Hardware Transactional Memory"
date:   2019-09-27 00:14:00 -0500
categories: paper
paper_title: "ForgiveTM: Supporting Lazy Conflict Detection on Eager Hardware Transactional Memory"
paper_link: N/A
paper_keyword: HTM; Conflict Detection
paper_year: PACT 2019
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes ForgiveTM, a bounded HTM design that features lower abort rate than commercial HTMs. ForgiveTM 
reduces conflict aborts by leveraging the observation that the order of reads and writes within a transaction is 
irrelevant to the order that they are issued to the shared cache, as long as these reads and writes are committed atomically 
and that the coherence protocol provides most up-to-date lines for each request. The paper also idientifies that currently 
available commercial HTMs are all eager due to the fact that Two-Phase Locking (2PL) style eager conflict detection maps 
perfectly to the coherence protocol. For example, a read-shared (GETS) request us equivalent to a read-only lock in 2PL,
while a read-exclusive request is equivalent to writer lock. During the execution, the cache controller monitors speculatively
accessed cache lines during the transaction, and sets the corresponding bit. When a conflicting request is received
from another core, the current transaction must be aborted to avoid violating the isolation propeerty. Past designs also
propose lazy conclift detection, which allows transactions to proceed after conflicts are detected, and only resolve these
conflicts at the time of commit (or abort if the transaction risks accessing inconsistent data). The lazy approach to
conflict detection, however, as pointed out by the paper, often requires modifications to the coherence protocol, which
is hard to design and verify, or assumes certain hardware structures that are difficult to implement (e.g. ordered 
broadcasting network). Lazy conflict detection usually provides better performance and lower abort rates for three reasons. 
First, the "vulnerabilty window", during which the transaction's reads and writes are exposed to other transactions, is smaller 
with lazy detection schemes. In contrast, eager schemes expose reads and writes as coherence states once they are performed
on the cache, and any coherence request will result in an abort. 