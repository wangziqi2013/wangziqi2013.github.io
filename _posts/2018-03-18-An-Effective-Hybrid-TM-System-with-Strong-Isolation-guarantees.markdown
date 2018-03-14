---
layout: paper-summary
title:  "An Effective Hybrid Transactional Memory System with Strong Isolation Guarantees"
date:   2018-03-08 22:53:00 -0500
categories: paper
paper_title: "An Effective Hybrid Transactional Memory System with Strong Isolation Guarantees"
paper_link: http://csl.stanford.edu/%7Echristos/publications/2007.sigtm.isca.pdf
paper_keyword: SigTM; Hardware accelerated STM; HybridTM
paper_year: 2007
rw_set: Signature for RS; Signature + Software hash table for WS
htm_cd: Lazy (FOCC)
htm_cr: Lazy (FOCC)
version_mgmt: Lazy, Software
---

This paper proposes SigTM, a hybrid TM implementation that features lazy CD/CR as well as software maintained 
write sets. Hardware cache coherence and cache tags are not changed. The processor is extended with the capability of
reading and writing RS and WS signatures. Incoming coherence requests are also tested with the signature to detect conflicts.

SigTM follows the STM methodology of instrumenting read and write instructions. Instead of providing fast and slow paths,
as most hybird TM does, SigTM uses hardware to accelerate STM, and has only one mode of execution. The read set is maintained
only on hardware as the read signature. The write set is maintained in both hardware signature, and in a software hash table.
Transaction commit and abort are handled by software runtime. Conflict detection is performed on the hardware level 
using cache coherence protocol.

In the transactional load handler, SigTM first searches the store signature. If a hit is produced, then the load is fulfilled
from the write set. Otherwise, the address is inserted into the read signature, and a load instruction is issued.

In the transactional store handler, SigTM inserts the store address into the store signature, and inserts the (addr., data)
into the software hash table. No hardware store on the target address is issued.

On cache line invalidation, SigTM checks whether the address is in the read signature. If the result is positive, then 
the transaction aborts. The write signature is not checked (even not NACKed).

In the pre-commit handler, SigTM validates its write set while keeping an eye on the conflicting pre-commits and 
read phase transactions. Write set validation is standard FOCC: SigTM tries to obtain exclusive permission for 
every cache line in its write set. In the meantime, four possible events may occur: (1) A read-exclusive request
comes from another processor and hits the write signature. This implies another processor is also performing pre-commit. 
The current transaction tries to serialize after the former by restarting the validation. (2) A read-shared request comes 
from another processor and hits the write signature. This implies another reader transaction establishes a new dependency 
with the current transaction. In this case, the validating transaction also restarts validation. (3) The read-exclusive 
request times out because of NACK. This implies another transaction is undergoing write back phase. The current transaction 
can only serialize after it by either waiting for a while, or restarting the validation process. (4) A read-exclusive
request comes from another processor and hits the read signature. This implies another processor is performing write validation,
and the current transaction has a read dependency with its write back phase. In this case the current transaction can only abort.

Once pre-commit succeeds, the transaction becomes "invincible" in a sense that it can no longer abort. The write set is
locked, such that all coherence requests will be NACKed