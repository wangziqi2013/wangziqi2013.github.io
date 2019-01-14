---
layout: paper-summary
title:  "Steal but No Force: Efficient Hardware Undo+Redo Logging for Persistent Memory Systems"
date:   2019-01-14 16:55:00 -0500
categories: paper
paper_title: "Steal but No Force: Efficient Hardware Undo+Redo Logging for Persistent Memory Systems"
paper_link: https://ieeexplore.ieee.org/document/8327020
paper_keyword: Logging; Durability; NVM
paper_year: HPCA 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a novel technique for performing logging on NVM backed systems that require atomic durability.
Such systems generally employ NVM as a direct replcement for DRAM, where memory reads and writes are issued in the 
same way via the memory controller and are finally served by the NVM connected to the bus using DIMM. In previous works,
two logging schemes are widely used to achieve durability: undo and redo logging. Undo logging saves the before-image 
of the memory location when a modification is about to be applied to the cache line. The before-image is then evicted
back to the NVM for persistence before the dirty line can be evicted. In case of failure, the recovery handler 
reads the undo log from the NVM, and reverts dirty modifications of uncommitted transactions using the before-image.