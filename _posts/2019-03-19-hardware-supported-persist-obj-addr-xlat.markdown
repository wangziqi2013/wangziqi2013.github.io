---
layout: paper-summary
title:  "Hardware Supported Persistent Object Address Translation"
date:   2019-03-19 20:15:00 -0500
categories: paper
paper_title: "Hardware Supported Persistent Object Address Translation"
paper_link: https://dl.acm.org/citation.cfm?id=3123981
paper_keyword: NVM; mmap; Virtual Memory
paper_year: MICRO 2017
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes a memory access semantics for NVM by accelerating memory address translation on hardware. Designing
data structures for NVM is a difficult task, not only because the data structure itself will remain persistent even between 
reboots and process or even OS sessions, but also because the way that NVM is managed differs from the convention way
people use DRAM. The paper assumes an architecture where DRAM and NVM are both attached to the memory bus, and shares 
a single physical address space. The NVM, however, is not mapped by the OS by default to avoid applications writing 
NVM, causing data corruption that can persist reboots (i.e. is impossible to fix). Instead, NVM is only exposed to users
by calling mmap(), which in turn allocates a chunk of virtual address space, and maps these VAs to PAs on the NVM. In the 
following discussion we call a VA mapped tp NVM addresses a NVM region. Exposing address spaces via mmap() suffers relocation
problem: If NVM data structures were written in the same way as volatile data structures, which use the value of virtual 
addresses of the target object as pointers, the NVM region must be mapped to the same base address every time the NVM object
is opened. This, as is the case for shared libraries, is hard to guarantee, because virtual address mapping can be affected
by many factors, such as multiple opened NVM objects, Address Space Layout Randomization (ASLR), conflicting addresses between
NVM region and the application, etc. If a NVM object is mapped to a different address than the one it is created, the 
value of pointers will be invalid, leading to undefined behavior for reads and data corruption for writes. 

This paper solves the problem of pointer relocation with composite pointers. Instead of using the absolute value of virtual 
addresses, pointers now are composed of two fields: A region ID and an offset. The region ID is a unique identifier of the 
NVM region assigned by the creator of the region. Region ID is defined in the header of the NVM object, which must be 
unique in the current session (the paper does not propose a solution for resolving region ID conflicts). The offset field 
stores the relative offset of the target address within the region, using the starting address of the region as the base. 
To convert a composite pointer to volatile virtual address pointers, the starting address of the region must be obtained, and
then added with the offset. 

Traditionally, obtaining the starting address of a region requires a table lookup, which is maintained by the NVM library.
A new region ID to base address mapping is inserted into the hash table after mmap returns successfully. If this is done 
by software routines, the call to which is inserted by the compiler every time before issuing a memory instruction, hundreds 
of extra cycles would be added to the critical path of memory access latency just to perform the table query. To get rid 
of such an expensive operation for every memory access, the paper proposes that we treat region ID as a new segmented address
space on top of virtual address space, and use special hardware to translate region IDs into virtual addresses at early stages 
of the execution pipeline. To achiveve this goal, two components are to be added: A Persistent Object Lookaside Buffer (POLB),
and a Persistent Object Table (POT). POLB serves similar functionality as a TLB, which caches translation information
from the page table. In the case of POLB, the mapping from region ID to the starting virtual address is maintained. The paper
also proposes adding two types of memory instruction, nvld and nvst, for reads and writes using composite pointers.
During the decoder stage of a nvld or nvst instruction, the decoder reserves a slot in the load store queue (LSQ) as for 
regular memory instructions. During the dispatch stage, after the instruction receives the value of the pointer from committed
instructions, it stays in the instruction window for at least two extra cycles before it can be issued for execution. In the 
first cycle, the address generation unit performs a POLB lookup using region ID in the address, obtaining the base VA.
In the second cycle, the unit then adds the base VA with the offset (zero extended), and finally generates the effective VA 
of the target. The VA is also entered into the reserved slot in the LSQ for disambiguation purposes (because other instructions
might be using the same VA to access the NVM location).