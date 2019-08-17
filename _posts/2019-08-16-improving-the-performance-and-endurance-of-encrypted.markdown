---
layout: paper-summary
title:  "Improving the Performance and Ensurance of Encrypted Non-Volatile Main Memory through Deduplicated Writes"
date:   2019-08-16 21:58:00 -0500
categories: paper
paper_title: "Improving the Performance and Ensurance of Encrypted Non-Volatile Main Memory through Deduplicated Writes"
paper_link: https://ieeexplore.ieee.org/abstract/document/8574560
paper_keyword: NVM; Counter Mode Encryption; Deduplication
paper_year: MICRO 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper unifies NVM encryption and deduplication into a simple machanism with both low latency and reasonable metadata storage
overhead. Encryption and deduplication are two important features for NVM based systems. Encryption avoids system data from
being leaked by physically accessing the NVM on a different machine after the current session is powered down. Since data
remain persistent on the NVM, runtime sensitive data protected by virtual memory machanism can be accessed directly if 
the device is taken down and installed on another computer. Deduplication is another technique that can both improve 
performance and endurance of the device by reducing the frequency of writes. NVM writes, being different from writes to DRAM
the latency of which can be overlapped with other instructions via the store buffer, are on the critical path. This is 
because in order to ensure the atomicity of a series of modifications, NVM writes generally require logging or shadow mapping
in order to re-apply the series of writes or undo a partial change after a system crash. Write orderings between the log entry
and the write entry must be enforced to guarantee the recoverability of the operation, e.g. for undo logging, the undo log entry
must be written into the NVM before the corresponding dirty block. 