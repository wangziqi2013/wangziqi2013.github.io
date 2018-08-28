---
layout: paper-summary
title:  "What Really Makes Transaction Faster?"
date:   2018-08-27 23:15:00 -0500
categories: paper
paper_title: "What Really Makes Transaction Faster?"
paper_link: http://people.csail.mit.edu/shanir/publications/TRANSACT06.pdf
paper_keyword: TL; STM
paper_year: TRANSACT 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes Transactional Locking (TL), a Software Transactional Memory (STM)
design that features low latancy and high scalability. Prior to TL, researchers have proposed
several designs that address different issues. Trade-offs must be made regarding latency,
scalability, ease of programming, progress guarantee, and complexity. Compared with previous
designs, TL highlights certain design choices which give it an advantage over previous STM
proposals. First, TL allows data items to be accessed without introducing extra levels of
indirection.
