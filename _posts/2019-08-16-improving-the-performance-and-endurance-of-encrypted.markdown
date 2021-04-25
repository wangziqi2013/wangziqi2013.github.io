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

3. The co-location of counter value and mapping table entries are a great contribution, especially that the inverse 
   mapping table uses real addresses rather than abstracted address
   

**Questions**

1. I personally don't buy the argument that using dedup will reduce traffic and put writes out of the critical path,
   because the dedup data structure should be persisted as well, which constitutes an NVM write to the hash table entry 
   and the reference count for each block eviction. One explanation is that the cache filters out the write to the metadata,
   then the question becomes how you write back the cache data on power failure?

2. The paper did not mention how caches are persisted back to the NVM, i.e. how to ensure that the update of the 
   hash table, the mapping tables and the cache block are conducted atomically? I understand that you may use 
   ADR as an excuse (as some previous publication point out) and say just make sure both updates are in the store 
   buffer before they are saved by ADR.

This paper unifies NVM encryption and deduplication into a simple machanism, DeWrite, with both low latency and reasonable 
metadata storage overhead. Encryption and deduplication are two important features for NVM based systems. Encryption avoids 
system data from being leaked by physically accessing the NVM on a different machine after the current session is powered 
down. Since data remain persistent on the NVM, runtime sensitive data protected by virtual memory machanism can be accessed 
directly if the device is taken down and installed on another computer. Deduplication is another technique that can both improve 
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

The paper then describes a concrete scheme for implementing deduplication. Four data structures are used to support
address remapping and space management of NVM. The first data structure is a mapping table, directly indexed by block 
addresses. Note that since DeWrite assumes 256 byte cache line and 32 bit address width, the mapping table only occupies 1/64
of the NVM storage to map from any arbitrary block to any arbitrary block on the device. The second data structure is a 
hash table, which stores the reference count of a block. The paper did not mention the internal structure of the hash
table including the conflict resolution algorithm, but the paper suggests that there can be multiple entries under a
same hash value due to conflict. Hash table entries are organized into (hash value, storage addres, ref count) tuples. 
When a cache block is to be written back, the CRC hash of the content is computed, and then used to probe the table. 
If an entry exists, then the existing block is read from the address, whose content is compared with the block to be evicted.
If the contents also match, the write will be cancelled because we have found a duplication. The reference count is incremented
by one, and the mapping table entry for the address to be evicted is updated to be the duplicated block. 

As the mapping table privides an association between the hash value and the storage address of a block, the third data
structure, an inverse mapping table, maps from the storage address to the hash table entry. This mapping table is 
consulted when a cache line is modified, which changes its mapped location. In this case, the inverse mapping table is 
consulted with the original storage address of the cache line (obtained from the address mapping table), which returns 
a pointer to the hash table entry. The reference count in the hash table entry is decremented by one (and GC'ed if 
the count reaches zero) before the new hash is computed. Note that if the reference count in the entry is about to overflow,
the NVM controller no longer allows more lines to be mapped to this entry. Instead, it allocates a new line on the device,
tolerating some degrees of redundancy. In practice, as long as the counter is reasonably long (8 bits) this is extremely rare.

The last data structure is a block allocation table, which uses bitmaps to indicate block being busy or not. Since a block
can be mapped anywhere on the device, this map is consulted when a new block is to be written, and deduplication could not
find a duplicated block.

The last contribution of the paper is based on the below invariant. At any moment in the runtime, for any address X, 
either the address mapping table entry of X is unused, or the inverse mapping is unused. Recall that the address mapping 
table maps block address into its storage address, if there is remapping, while the inverse mapping table maps the storage 
address to the hash table entry (if there is a valid block). For entry X, there are two cases. If X has been remapped to
a new location, the mapping table entry of X is occupied and cannot be used for other purposes. The inverse mapping, however,
must be valid, because the cache block to be written here has been remapped. If, on the othre hand, address X could not be 
deduplicated, then it has to be written into storage address X (i.e. identify mapping, which can be encoded using one bit
in the mapping table), in which case the inverse mapping stores the pointer to the hash table entry. Since we assume 
32 bit address width, 31 bits of them are usable to store data for other purposes, and we only dedicate one bit to indicate 
whether this is an identify mapping. Taking advantage of this invariant, the paper suggests that the counter of block 
can be co-located with the two mapping tables on entry X, eliminating dedicated storage for counters.