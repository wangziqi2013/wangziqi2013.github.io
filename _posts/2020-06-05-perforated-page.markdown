---
layout: paper-summary
title:  "Perforated Page: Supporting Fragmented Memory Allocation for Large Pages"
date:   2020-06-05 11:24:00 -0500
categories: paper
paper_title: "Perforated Page: Supporting Fragmented Memory Allocation for Large Pages"
paper_link: https://www.iscaconf.org/isca2020/program/
paper_keyword: Virtual Memory; Perforated Page
paper_year: 
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes perforated page, a virtual memory extension for supporting huge pages with little memory fragmentation
overhead. Existing huge page support on commercial processors rely on the OS's ability to find large physical address 
chunks which can then be mapped to an aligned 2MB virtual address range. Huge pages reduce the number of TLB entries
for mapping a consecutive range of memory than using regular 4KB pages. This design, however, has to overcome several 
difficulties such as memory fragmentation and data movement overhead. The paper identifies three major challenges 
while using huge pages. The first challenge is memory bloating, which happens when a huge page is only sparsely accessed.
Since huge pages must be assigned physical storage as a whole, most memory storage is wasted. With regular 4KB page,
this will not be an issue, since each 4KB page can be mapped individually. This is especially problematic if the OS
has Transparent Huge Page (THP) enabled, in which the OS's VMM detects allocation pattern that can fit into a huge page,
and automatically use huge pages to satisfy the allocation. The OS has no idea about the access pattern of these allocated
huge pages, resulting in possible mismatch between page size and access density.
The second challenge is deduplication, which is implemented by some application level software and/or the OS kernel.
The deduplication process tries to find identical pages mapped by different processes, and then remap them to the same
physical frame. With 2MB huge page, the chance that an iddentical page be found is most likely small, since a single byte
within the 2MB range will render deduplication impossible. As a result, the OS needs to actively decompose huge pages 
previously allocated into standard 4KB pages. This not only creates extra memory management overhead, but also increases
TLB pressure, since more entries are needed to map the same physical memory. 
The last challenge is posed by the fact that the OS will also actively compact physical pages to reduce fragmentation,
and then promote large chunks of memory into huge pages. The background compact and promoting process incurrs extra 
memory traffic, since physical pages are copied around for defragmentation. 

Perforated page design solves the above issues by allowing huge pages to be mapped with an unlimited number of 4KB "holes" 
in the virtual address space, making the 2MB virtual address range partially non-consecutive. These holes in the 2MB page
serve three differeit purposes. First, virtual address holes do not need to be backed by any physical pages. If a hole
is known to be never accessed by the application, the physical page backing the hole can be released, which increases
memory utilization. Second, even if holes are backed by physical memory, they enable the OS's VMM to somehow exert finer
grained management over the mapped page. In the deduplication examples above, a deduplicated "hole" page can be individually 
allocated, if it is to be mapped by multiple different processes. The last purpose is that 2MB pages can be mapped with
a physical address layout which contains valid 4KB pages in the 2MB physical range. As long as virtual addresses that
correspond to these valid pages are remapped as "holes", even a highly fragmented physical address layout could support
huge page mapping, eliminating the need of memory defragmentation.

Perforated design consists of two major components: Extended page table for extra level of mapping, and a modified L2
TLB organization and lookup protocol. We discuss these two in the following paragraphs.

In order to map 4KB pages within a 2MB huge page, an extra level of page table entry must be added below the 2MB table
entry. In addition, the page table must also contain information to identify which aligned 4KB address ranges are 
individually mapped as "holes". Both information must be easily located since they are on the critical path of 
page table walks. The paper proposes that the extra level of indirection can be located right next to the main
page table, and calls it "shadow page table". When initializing a page table for perforated pages, the OS should
allocate two pages, instead of one, when creating the page table entry. The shadow table entry has the same format
as a last-level page table entry for mapping 4KB pages, with the same layout for base address and permission bits.
The extra bit vector, however, does not fit into any table entry, since there are 512 bits (64 bytes) in total.
The paper proposes a two-level hiararchy for the bit vector. First, precise bit vectors are stored globally in a direct-mapped
memory region in the physical address space, which is initialized on system startup. The bit vector stores mapping
information for all 4KB physical frames, with "1" bit indicating that the physical frame is a "hole", and "0" bit
otherwise. The overall overhead for the bit vector is small for two reasons. First, it takes only one bit to map a 4KB 
physical page, resulting in a total storage overhead of only 0.003%. Second, the bit vector maps physical address space
rather than virtual address. The actual cost of the bit vector is propotional to the amount of physical memory installed,
rather than the size of virtual address space which can be huge.

The second level of the bit vector is stored in the page table entry of the 2MB page mapping, taking advantage of unused
bits. The paper suggests that 8 unused bits are used as a coarse-grain filter to quickly rule out 4KB regions that are 
not holes. During a page walk, the second level bit vector is accessed and checked first. If the bit is set, then the 
first level bit vector is further accessed from the global bit vector, addressed with the translared physical address.
A "1" bit in the global bit vector indicates that the shadow table entry should be accessed, the address of which can 
be computed easily by adding 4KB to the base address of the main table entry. The paper also notes that the first level
bit vector for a 2MB page consists of 512 bits or 64 bytes, which can be read out with exact one extra memory access.
The global bit vector can also be cached in the cache hierarchy for accelerated access in the future.

The TLB lookup protocol is modified as follows. First, for perforated pages, the 2MB entry is only cached by L2 TLB.
The paper made a design decision of not adding any extra bits in L1 TLB to avoid radically changing L1 TLB access 
latency or complexity, which is of critical importance for fast memory accesses. The consequence is that L1 TLB could
not distinguish between a perforated page and a hole within the page, if 2MB entries are cached. To address this problem,
only L2 TLB is allowed to cache translation for 2MB perforated pages. Holes are also cached in the L2 TLB as individual
4KB entries. The L2 lookup logic must try both sizes in parallel on a lookup request, and always give priority to 4KB
translations, if one is found. The paper did not, however, mention how the lookup logic can be realized on modern L2 TLBs, 
since the actual implementation of L2 TLB may be two independent structures with a page size predictor. Accessing both
banks in parallel requires non-trivial changing of the lookup logic. After an L2 entry is found (assuming a hit), 
an L1 TLB entry is generated by the lookup logic, and then inserted into L1 TLB. The generated entry does not physically 
exist in the page table, if it is from non-hole area of the perforated page. 

On an L1 TLB eviction, the evicted entry should be merged with L2 entry in terms of access and dirty bits. Given that
the evicted entry may not physically exist in the L2 TLB, the insertion logic of L2 TLB should check whether the 
evicted entry is generated earlier by the lookup logic, and merge both bits into the 2MB mapping entry if it is the case.
The paper did not mention this either.

If L2 TLB lookup signals a TLB miss, the page walker is invoked to lookup the page table. On reaching the page table entry
for the 2MB page, the page walker checks whether the target address is a hole, or it lies within the 2MB page using the 
algorithm described earlier. If the target address is a hole page, then the shadow table entry is accessed, and the 4KB
base address is returned. Otherwise the 2MB physical address is returned. The page walker should indicate to L2 TLB on
the type of page that is actually returned. The corresponding entry is then inserted into both L1 and L2 TLB, before 
the request is fulfilled.

L2 TLB hit logic is also changed. If only 2MB entry is hit, the L2 TLB lookup logic should always lookup the bit vector
to determine whether the hit is actually on a 4KB hole (if entries of both types are found, then it must be a 4KB hole). 
To avoid having to access the bits in the page table and/or global bit vector arraay for each L2 TLB hit, the paper proposes 
that the bit vector also be cached in L2 TLB entries. A special mode bit is added per-L2 entry to indicate the storage mode. 
Address tags are also needed to determine the offset of these bit vectors within the 2MB page. Bit vectors are brought 
into the L2 TLB on-demand, i.e. they are only installed when a page walker returns them as a result of the page walk. 
The paper claims that at most 17 entries are needed to store the L2 TLB entry and the bit vector, while the number is 
512 entries in the case of 4KB pages. This comparison, however, is incorrect, since in the worst case, the 512 4KB mapping
entries are also inserted into the L2 TLB.
