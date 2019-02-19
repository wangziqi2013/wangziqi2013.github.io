---
layout: paper-summary
title:  "Hiding the Long Latency of Persist Barriers Using Speculative Execution"
date:   2019-02-19 17:19:00 -0500
categories: paper
paper_title: "Hiding the Long Latency of Persist Barriers Using Speculative Execution"
paper_link: https://ieeexplore.ieee.org/document/8192470
paper_keyword: NVM; Persist Barrier; Speculative Execution
paper_year: ISCA 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---  

This paper proposes speculative persistence, a microarchitecture technique that allows processors to execute past a 
persistence barrier. A persistence barrier is a special instruction sequence that stalls the processor until previous
cached store operations are acknowledged by the memory controller. It is particularly essential in NVM applications
where the system state is persisted onto the NVM to enable fast crash recovery. Many existing proposals use undo
logging, where the value of data items (e.g. cache line sized memory blocks) are first recorded in a sequential log
before they are modified by store operations. On recovery, the undo log entries are identified, and partial modifications 
are rolled back by re-applying all undo log entries to the corresponding addresses. 

This paper assumes a static transactional model. Persistence is achieved by wrapping operations within static transactions. 
Either all store operations within a transaction are persisted as an atomic unit, or none of them is persisted. On recovery,
partial transactions are rolled back using undo log as described in the previous paragraph. Transactions execute as follows.
First, locations that are to be stored into are identified, and log entries containing their old values are generated. 
Second, these log entries are flushed to the NVM by issuing a persist barrier. Next, the transaction begin record is written
and flushed into the log to indicate that after this point, dirty cache lines might be evicted back to the NVM. Then, the 
transaction body is executed as usual, during which dirty cache lines might be written back to the NVM due to eviction.
Lastly, dirty cache lines are flushed back to the NVM using another persistent barrier, after which the transaction end 
record is written and then flushed using the fourth persistence barrier. On recovery, the recovery handler reads the sequential
log in reverse order. For every uncommitted transaction in the log, it first checks whether the transaction has begun by 
locating the transaction begin record. If the log has undo log entries, but the transaction actually did not begin, these 
undo log entries are discarded, because it is guaranteed that no dirty cache lines from the transaction can ever reach NVM. 
Otherwise, undo entries are applied. 


