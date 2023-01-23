---
layout: paper-summary
title:  "Libnvmmio: Reconstructing Software IO Path with Failure-Atomic Memory-Mapped Interface"
date:   2023-01-23 00:03:00 -0500
categories: paper
paper_title: "Libnvmmio: Reconstructing Software IO Path with Failure-Atomic Memory-Mapped Interface"
paper_link: https://www.usenix.org/conference/atc20/presentation/choi
paper_keyword: NVM; Libnvmmio; File System
paper_year: USENIX ATC 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents libnvmmio, a user-space file system extension to support efficient failure-atomic semantics 
on Byte-Addressable Non-Volatile Memory (NVM). Libnvmmio acts as an intermediate module between the user space system 
call interface and the existing memory-mapped file interface. Libnvmmio lowers the software overhead of the legacy 
read/write interface and implements an epoch-based persistent model that allows dirty data to be persisted in an
orderly manner.


