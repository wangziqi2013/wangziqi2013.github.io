---
layout: paper-summary
title:  "Scalable Logging Through Emerging Non-Volatile Memory"
date:   2019-02-01 17:27:00 -0500
categories: paper
paper_title: "Scalable Logging Through Emerging Non-Volatile Memory"
paper_link: https://dl.acm.org/citation.cfm?id=2732960
paper_keyword: ARIES; Recovery; Logging; NVM
paper_year: VLDB 2014
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---  

This paper proposes distributed logging, a mechanism that extends ARIES-stype database recovery algorithm
to provide support for scalable logging on multicore. The traditional ARIES algorithm provides a general-purpose, efficient,
and versatile solution for database recovery, which requires only simple data structures and a few extension to an existing
database system. The core of ARIES is a software maintained sequential log, in which log entries of different types
are stored. Log entries are identified by their unique Log Sequence Number (LSN), which corresponds to their logical 
offsets into the log. Although not explicitly mentioned in the paper, in order to append an entry into the log, the 
transaction should acquire both a page latch and a log latch. The former is to ensure that two different transactions
modifying the same page should append their entries in the same order as they conduct the modification. The latter is to
protect the integrity and consistency of the log itself, preventing concurrent modifications corrupting the log data 
structure. 

