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

**Highlight:**

1. Using larger blocks (256B) to reduce metadata overhead. Similarly, the paper assumes 32 bit device address, which reduces
   the length of the two arrays.

2. Results with 3-bit dedup predictor is very impressive. I did not expect the clustering of blocks that can be dedup'ed 
   to be this strong.

**Lowlight:**

1. I personally don't buy the argument that using dedup will reduce traffic and put writes out of the critical path,
   because the dedup data structure should be persisted as well, which constitutes an NVM write to the hash table entry 
   and the reference count for each block eviction. One explanation is that the cache filters out the write to the metadata,
   then the question becomes how you write back the cache data on power failure?

2. The paper did not mention how caches are persisted back to the NVM, i.e. how to ensure that the update of the 
   hash table, the mapping tables and the cache block are conducted atomically? I understand that you may use 
   ADR as an excuse (as some previous publication point out) and say just make sure both updates are in the store 
   buffer before they are saved by ADR.

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
must be written into the NVM before the corresponding dirty block. In the meantime, the processor can only wait until the 
store buffer is drained before the log write is persisted. This not only doubles the traffic to the NVM, but also forces 
the processor to stall, which puts the write operation at the critical path of execution. Depending the workload, deduplication 
can eliminate some direct writes to NVM by mapping a newly created block to an existing on already on the device.

This paper identifies several problems from previous works on NVM deduplication and encryption, and both. First, many
encrytion framework relies on cryptographic algorithms such as AES or MD5 to hash a block into a shorter identifier. The 
hardware computation of such functions are slow and energy hungry, and even worse, on the critical path. Second, deduplication
and encryption, when performed together, are inevitably serialized. The system first identifies whether the block to be written
is a duplication of an existing block, and if not, the block is then encrypted and written. Although these two can be parallelized
by speculatively encrypting the block while deduplication is running, and cancelling the encryption process if the block
is confirmed to be a duplication, this parallelization wastes energy and hardware throughput by unnecessarily encoding 
a block when a duplication happens. The third problem is that most previous publications (at least those cited by the paper)
did not attempt to reduce metadata storage of either by exploring the possibility of co-locating their metadata.

The paper assumes counter-mode encryption in which a counter is incremented every time a cache block is to be written back.
The counter value, together with the address of the block and a private key, is used to generate a one-time padding of the 
block size, which is then XOR'ed with the cache block as the encrypted block. The counter value should also be written back
to the NVM atomically (using ADR or logging) with the dirty block. One of the advantages of counter mode encryption is that
on read operation, the counter can be accessed from a fast cache, and the generation of OTP is largely overlapped with 
the fetch of the block from the NVM. After the block has been fetched, the only latency change on the critical path is
an extra XOR operation.

This paper proposes using a hardware predictor to solve the second problem above. The observation made by the paper is 
that duplicated blocks are often clustered, i.e. most of them are produced in a small window, which makes prediction 
feasible. The predictor is very simple: only three bits are used to remember the most recent three block writes. 
The majority of the three bits is used as the prediction output. If the predictor indicates that the block might be 
a duplication, then we run deduplication and encryption serially, because there is a large chance that the last step
is not needed. If, on ther other hand, the predictor indicates otherwise, then we run both in parallel such that the 
critical path is only the longer of these two. Evaluation shows that three bits are sufficient to reach a prediction
success rate of > 92%, which confirms the paper's observation. Note that whether the prediction is correct or not,
the predictor state can always be updated using the result of deduplication. 