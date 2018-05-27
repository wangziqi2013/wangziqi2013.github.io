---
layout: paper-summary
title:  "Coherence protocol for transparent management of scratchpad memories in shared memory manycore architectures"
date:   2018-05-25 20:20:00 -0500
categories: paper
paper_title: "Coherence protocol for transparent management of scratchpad memories in shared memory manycore architectures"
paper_link: https://dl.acm.org/citation.cfm?id=2749469.2750411
paper_keyword: Coherence; Scratchpad Memory
paper_year: ISCA 2015
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
--- 

Scratchpad memory (SPM) is small and fast on-chip memory that allows easy accesses by applications. Compared 
with the cache hierarchy, SPM is nearly as fast, but is more power efficient. The biggest difference between
SPM and the cache is that SPM requires explicit software management in order to transfer and synchronize data,
while the cache controller manages data in cache line granularity to maintain transparent access. From one perspective,
the flexibility of programming with SPM enables the application to take advantage of application-specific knowledge
and optimize it further. On the other hand, difficulties may arise as a result of lacking coherence support 
directly from the hardware. 

This paper aims at solving the coherence problem between SPM and the memory hierarchy. The operating model of 
SPM is described as follows. In a multicore system, each core has a private SPM that is only accssible to that core. 
A DMA engine transfers data between the SPM and main memory. The application is able to issue synchronous DMA 
commands via memory-mapped I/O. Memory copies between the SPM and DRAM are not coherent. The application
is responsible to copy back dirty values to main memory. Both the virtual and physical address spaces are divided 
into conventional memory and SPM. The systems uses a few registers to inform the MMU of the address range allocated to 
SPM. The MMU perform a direct mapping from virtual address to physical address if the virtual address belongs to SPM. 
The memory controller then diverts physical addresses that are mapped to SPM to the SPM controller. 

The hybird SPM and main memory architecture works well if the data access pattern is regular and can be known 
in advance. One of the examples is HPC computing, where a dominant number of workloads access memory in a strided 
manner. The compiler is responsible for moving data between the main memory and SPM by calling into the SPM runtime 
library. Before a data structure can be accessed in the SPM, a DMA call that moves the data from main memory to
SPM is issued. After that, all references to the data structure is replaced by references to the corresponding copy
in the SPM. After the access, depending on whether the SPM copy is dirty, a second DMA transfer that copies back the 
modified data structure may also be issued by the compiler. 

One notable variant of the hybrid SPM-main memory system simplifies the coherence problem by using static mapping. 
In the static mapping scheme, variables are declared as SPM resident, and the compiler automatically generates 
instructions to access the SPM if these statically mapped variables are accessed. Compared with the dynamic mapping 
scheme where variables can be moved between the SPM and main memory, the address of a variable in the static scheme remains 
unchanged throughout the lifetime of the application. Maintaining coherence in this case is trivial, as there is no 
duplication between SPM and the main memory. This scheme, however, is totally ignorant of the dynamic property of the 
application, and could be inferior compared with the dynamic mapping scheme. 

The coherence problem arises when an instruction accesses a data item in the main memory (including caches), while 
a potentially updated copy may in the meantime exist in the SPM. The target address of the instruction should 
therefore be redirected to access the SPM. Note that instructions that access the SPM should never be redirected, as the 
programming model uses DMA for explicit synchronization. If the copies of data items differ between the main memory and 
SPM, then it is guaranteed that the SPM must have the most up-to-date copy. The problem becomes aggravated in a multicore
environment, where each core has its own SPM. In addition to checking the SPM mapping on the current core for every 
suspicious load/store instruction, the SPM mapping of other cores must also be checked.

Given that multiple SPM mapping potentially needs to be checked on a single memory instruction, the coherence protocol 
needs a central directory that can be queried for the identity of an address. A naive implementation would be letting
the core that issues the instruction to broadcast the request with the target virtual address. Any processor that has 
the address mapped to SPM should reply with data (for load) or apply the change (for store) on behave of the 
requesting processor. Otherwise the address is not mapped to any SPM, and the main memory is accessed after MMU 
translates the address. Note that since SPM storage cannot be invalidated (exactly one copy is maintained), the coherence 
protocol here must be updated-based, rather than invalidation-based. As with any broadcast-based system, the naive design
lacks scalability. Even worse, performance will plunge if a broadcast is issued for every memory instruction. As 
we shall see from later sections, broadcast is only used when information about the mapping is unavailable.

To support coherence only on a subset of instructions, the ISA is extended in a way that distinguishes between normal load/store
and guarded load/store. A normal load/store instruction always accesses memory based on the address space division. If the address
belongs to main memory, then the SPM will not be checked. Guarded instructions, on the other hand, checks whether the address is 
mapped by SPM. The target address of the instruction is diverted to access the SPM if a copy exists. 

The compiler is supposed to perform an aliasing analysis, and determine whether a load/store should be in its guarded form.
If a memory instruction is known to be always accessing the local SPM or the main memory, then normal instructions are issued. 
Otherwise, the compiler issues guarded instructions, and let the hardware determine in the runtime whether the address
should be diverted to some SPM or the main memory.

Each core maintains a fully associative array that stores active virtual to SPM address mappings. The array is searched using 
virtual addresses when external coherence requests arrive. Besides that, each core also has a local filter, which stores addresses
that are known to be not part of any SPM mapping. As local and remote cores add new SPM mappings, the content of the filter may 
become obsolete, and must be notified of any local or remote update. To enable efficient notification, a central filter directory of 
filters are added to the memory controller as part of the cache directory. The filter directory tracks which cores have which 
addresses in their filters. It is a large fully associative buffer that maps virtual addresses to a bit mask. The length of 
the bit mask equals the number of processors in the system, and the corresponding bit is set if a processor has the address 
in its filter. All addresses mentioned in this paragraph are base addresses of fixed sized chunks. We assume that all chunks 
must be mapped to SPM using the same granularity and alignment. The granularity is determined in the runtime by the compiler.
The SPM interface allows the application to specify the granularity of mapping by setting the values of a base mask register and 
offset mask register.