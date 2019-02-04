---
layout: paper-summary
title:  "Storage Management in the NVRAM Era"
date:   2019-02-03 18:41:00 -0500
categories: paper
paper_title: "Storage Management in the NVRAM Era"
paper_link: https://dl.acm.org/citation.cfm?id=2732231
paper_keyword: ARIES; Recovery; Logging; NVM; Group Commit
paper_year: VLDB 2013
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---  

This paper seeks to get rid of centralized logging in classical database recovery schemes such as WAL and ARIES which is 
also based on WAL. The classical WAL is designed specifically for disk-like devices that feature a block interface 
with slow random I/O, but faster sequential I/O. One of the examples is ARIES, where a software-controlled buffer pool 
is used to provide fast random read and write access to disk pages. The buffer pool must observe the WAL property in order 
to guarantee that transactions can always be undone after a crash. In addition, ARIES maintains a centralized log object 
to which all transactions append their log entries. Every log entry has an unique identifier called a Log Sequence Number (LSN).
The log object supports the "flush" operation, which writes back all log entries before a given LSN to the disk. The 
flush operation is usually called when a page is to be evicted from the buffer pool, and when a transaction has completed 
execution and is about to commit. In the former case, the log is flushed upto the LSN of the most recent log entry
that wrote the page, while in the latter case, all log entries written by the committing transaction (and hence all log 
entries with smaller LSN) should be written back.