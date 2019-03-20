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
of the target. The VA is also entered into the reserved slot in the LSQ for disambiguation purposes, because other instructions
might be using the same VA to access the NVM location. The NVM memory operation is finally issued to the cache in the memory 
access stage of the pipeline.

At dispatching stage, if the POLB signals a miss, the instruction must be stalled in the instruction window while a 
hardware page walker fetches region ID mapping from the main memory. The region ID to VA mapping is maintained by the 
Operating System. A new entry is inserted into the table whenever mmap() is called for allocating a chunk of VA mapped 
to NVM address space, and removed when munmap() on the VA is called. One observation made by the paper is that only
a few region IDs will be opened for typical scenarios. The mapping table therefore does not need to be large and complex, 
but must be efficient. The paper proposes using a hash table with linear probing. The hash table is initialized as an array
of 16K table entries. The page walker first hashes the lookup key, i.e. the region ID, to an index, and scans the array until
a matching entry or an empty entry is found. In the latter case, the lookup key does not exist in the table, and the MMU
signals the processor to raise an exception, because an invalid region ID is used to access memory.

The paper also proposes another solution that maps region ID directly into the physical address of the NVM region, hence
passing the address translation stage of memory access. With the physical address design, the memory operation can be 
initiated as soon as the address is available from decoding stage, because the cache set can be pre-activated using lower 
bits of the address, which are completely included by the offset field. This is similar to how cache set activation
is done in parallel with TLB lookup. This design, however, faces multiple problems that hinders both correctness and efficiency.
First, the correctness of load-store reordering cannot be guaranteed if the LSQ uses VA, because the instruction bypasses 
VA generation, and the hardware only knows PA. If a load instruction using composite pointer is after a store instruction to
the same VA using a volatile pointer, the load instruction may fail to observe the value written by the latter, because 
the LSQ may fail to recognize that they access the same part of the memory and miss the load forwarding. Second, if 
region ID is directly mapped to physical addresses, the tag size must be larger than the one in region ID to VA design.
This is because the underlying physical address on NVM address space may not be consecutive. This design actually maps
region ID and page offset from the beginning of the region to a physical page. Based on the same reason, more mapping entries 
are actually needed, because now every page in the NVM region requires a mapping, instead of every opened object.