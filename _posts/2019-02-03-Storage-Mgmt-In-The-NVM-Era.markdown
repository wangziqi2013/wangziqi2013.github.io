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
also based on WAL. The classical WAL is designed specifically for disk-like devices that features a block interface 
with slow random I/O, but faster sequential I/O. In ARIES, a software-controlled buffer pool is used to provide fast
reads and writes to disk pages. The buffer pool must observe the WAL property in order to guarantee that transactions 
can always be undone after a crash. 