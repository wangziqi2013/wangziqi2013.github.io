---
layout: paper-summary
title:  "Easy Lock-Free Indexing in Non-Volatile Memory"
date:   2019-11-09 17:33:00 -0500
categories: paper
paper_title: "Easy Lock-Free Indexing in Non-Volatile Memory"
paper_link: https://icde2018.org/index.php/program/research-track/long-papers/
paper_keyword: MWCAS; NVM
paper_year: ICDE 2018
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents PMWCAS, a programming primitive featuring both multiword atomicity and durability for constructing 
persistent and lock-free data structures. This paper lists a few advantages of using PMWCAS as the building block for
data structures compared with ad-hoc mechanisms specialized for certain programming paradigms. First, MWCAS simplifies
parallel data structure design and preogramming due to its strong semantics. With MWCAS, arbitraty number of words can 
be compared and swapped in an atomic manner, which greatly benefits pointer-based data structures, in which a single
operation typically involves changing several pointers and fields at different locations. Conventional lock-free programming
using single word CAS must guarantee that each CAS transforms the data structure into a valid intermediate state, and that 
threads must "help-along" on these intermediate states to ensure progress and proper synchronization. Second, MWCAS unifies
atomicity and persistency into the same framework. The descriptor-based implementation of MWCAS provides both atomicity
and persistency, while in ad-hoc data structures, thread synchronization and persistence are often implemented by two distinct 
mechanisms. The third reason is that MVCAS does not rely on specialized recovery and memory reclamation procedures to work.
The programmer can simply wrap any multi-word atomic operation with MWCAS library, and recovery is handled automically after 
crash. For memory reclamation, MWCAS implements its own epoch-based reclamation policy which delays the deallocation of 
memory blocks until all threads have dropped their references to the block. This epoch-based mechanism is integrated
into MWCAS both as its internal memory reclamation policy, and also exposed to users for better code reuse. The authors
also compared their software MWCAS with HTM. The conclusion is that HTM performs slightly better than MWCAS in performance,
but its unstability (no progress guarantee due to spurious aborts) and lack of persistence support make MWCAS a better choice
in general.

MWCAS provides a set of interface for users to add, remove, and update CAS entries. Every MWCAS instance is represented by
a descriptor, which contains the metadata for performing the MWCAS operation. The paper suggests that descriptors be stored
in a known location on the NVM, such that they can be found after the crash. MWCAS entries are partitioned between threads,
such that threads do not need to synchronize when they need one. A MWCAS entry consists of a status word representing the 
current state of the operation, and an array of entries for storing metadata. MWCAS metadata includes the address of the 
target word, the old value to be compared, and the new value to be swapped. The paper also assumes that the target words 
of MWCAS are either pointers, or small numerical values (much smaller than 2^64), or bit fields. In all three cases, 
we can reserve three bits for denoting the current state of the value. According to the value of the bits, a target word 
may contain either the original value, or the updated dirty value (if MWCAS succeeds), or a pointer to descriptors. The 
paper suggests that two bits should be used to indicate whether it is pointer to MWCAS or RDCSS (see below) descriptor,
and one "dirty" bit is to indicate whether the value has not been flushed back to NVM. If none of the three bits is 
set, the value is considered to be non-dirty and non-descriptor, which can be accessed directly. Otherwise, we need to
mask off these three bits, and act accordingly based on the type of the value, which we will describe below.

The MWCAS operates in two stages. In the first stage, the thread initiating the MWCAS first allocates a descriptor
from the pool, populates the descriptor with MWCAS entries, and persists the entry. The status word in the descriptor is
initialized to "Undetermined". This needs to be done before the descriptor is linked to the data structure to avoid 
undefined recovery behavior if the system crashes right after it is linked. Then the thread enters first stage, during
which it "locks" all target words in the descriptor in a manner similar to 2PL. The thread first sorts the addresses in
the MWCAS descriptor, and then performs a "restricted double compare and single swap" (RDCSS) on the target word and the 
status word of the descriptor, with "old" in the entry as old value for the target word, and the pointer to the descriptor 
as "new" for the target word. The status word is only compared by the RDCSS but now swapped, and the value used for the 
comparison is the state constant, "Undetermined". This extra comparison is to avoid a subtle ABA race condition, in which 
two threads contend to finish the same MWCAS. Assuming we only use single word CAS to post descriptor pointers. In this 
case, the first thread X first posts a descriptor, and then thread Y sneaks in, sees the descriptor, and "helps along" 
to finish the MWCAS, updating all target words and changing the status word to "Completed". Then thread Y conducts another 
MWCAS which reverts one of the target words A in the previous MWCAS to its old value. And finally, thread X wakes up, 
attempts to post the descriptor on A, and the single word CAS succeeds since it sees the expected value on A, despite
the fact that the first MWCAS has already been completed by thread Y. In this case, the first MWCAS is both serialized
before the second CAS by having it observing its update, and serialized after the second CAS by overwriting its update
on the same target word, violating the definition of atomicity. The problem is solved by checking both the target word
and the status word using RDCSS, which only installs the descriptor pointer when the target word matches the old value
in the entry, and the status word is still "Undertemined", meaning the MWCAS is still active. Also note that when installing
the pointer, we should set one of the two bits in the pointer to indicate that the value is a pointer to descriptors
rather than a regular value (MWCAS and RDCSS uses one bit, respectively). On seeting these bits, threads should "help-along" 
and finish the MWCAS before it proceeds to finish its own job.

To avoid deadlock, when installing pointers to target words, threads must first sort the address, and only install pointers
using a globally agreed order (e.g. low to high or high to low). Otherwise, threads may be trapped into infinite recursion
when they try to "help-along" each other.

The first stage ends successfully after all target words are updated with the descriptor pointer the using RDCSS. We 
commit the MWCAS by atomically changing the status word from "Undetermined" to "Completed" using single word CAS. Note 
that this must be done using CAS, since concurrent threads might have already finished the MWCAS by chaging the status 
word to another value. If this CAS fails, the thread should just re-check the status word, and then act accordingly. 
We then flush the status word using clwb and a memory fence. After the memory fence instruction returns, the MWCAS is fully
committed, since at this moment, all updates can be redone after a crash. 