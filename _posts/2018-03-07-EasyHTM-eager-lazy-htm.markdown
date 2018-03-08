---
layout: paper-summary
title:  "EasyHTM: Eager-Lazy Hardware Transactional Memory"
date:   2018-03-07 22:37:00 -0500
categories: paper
paper_title: "EasyHTM: Eager-Lazy Hardware Transactional Memory"
paper_link: https://timharris.uk/papers/2009-micro.pdf
paper_keyword: Conflict resolution; Directory based coherence; 2 Phase Commit
paper_year: 2009
rw_set: L1 Cache
htm_cd: Eager
htm_cr: Lazy
version_mgmt: Lazy
---

This paper proposes an restricted HTM design that decouples conflict detection (CD) from conflict resolution (CR). 
Early conflict detection (CD) has certain disadvantages. 