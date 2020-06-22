---
layout: paper-summary
title:  "Concurrent Support of Multiple Page Sizes On A Skewed Associative TLB"
date:   2020-06-21 05:29:00 -0500
categories: paper
paper_title: "Concurrent Support of Multiple Page Sizes On A Skewed Associative TLB"
paper_link: https://dl.acm.org/doi/10.1109/TC.2004.21
paper_keyword: Skewed TLB; TLB
paper_year: Technical Report 2003
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This technical report proposes a noval TLB design, skewed associative TLB, in order to support multiple page sizes
with a unified TLB. MMU nowadays support multiple granularities of page mapping, with page sizes ranging from a few KBs 
to a few GBs. This introduces the problem of correctly finding the translation entry given a virtual address, since the 
page size of the address is unknown before the entry is found. In conventional set-associative TLBs of only one page 
size, the lowest bits from the page number of the requested virtual address is extracted as the set index. 
The virtual page number is easily from the requested address, since the page size is fixed. For TLBs with multiple 
page sizes, since the lowest few bits of the page number itself is a function of page size, using these bits as the 
set index is infeasible.

There are four different proposals to solve this problem. First, the TLB can be made fully associative to avoid having
to extract the set index from the page number at all. All TLB entries are extended with a "mask" field, which is derived
from the page size of the PTE when it is inserted into the TLB. The tag stored in the entry is the actual virtual
page number, with lower page offset bits setting to zero. The "mask" field is AND'ed with the requested
virtual address on a lookup, masking off lower bits of the address. On a translation request, the requested virtual address 
is AND'ed with all "mask" fields respectively, and then compared with tags of all entries. A hit indicates that a valid 
translation exists. Having a fully associative TLB, however, requires activating all entries on all memory requests.
The extra read and comparison logic would pose a challenge for both area and power consumption.

The second type proposal divides TLB resources statically into several smaller TLBs (i.e. into smaller number of ways), 
each responsible for a size class. On a TLB lookup, all smaller TLBs are looked up in parallel using the static page
size mask assigned to each of them. Results are also checked in parallel, and the page size is determined by the 
size class of the TLB that signals the hit.
This approach may result in sub-optimal allocation of resource, since TLB entries are divided statically. If the actual
usage pattern disagrees with the static division, some TLB slices will be underutilized, while others undergo contention.
(Thoughts: What if I can dynamically adjust ways or even sets using a predictor?)

The third proposal is that multiple indices of different page sizes are generated in parallel, and then potentially 
multiple different sets are probed for tag check. This proposal will considerably increase the access latency of the
TLB, since it is generally impossible to read multiple sets in the same cycle, as most tag banks have only a limited
number of read ports. Besides, the power consumption of the TLB would be several times of the baseline design, since
more decoding and tag comparison operations are performed.
(Thoughts: If we partition sets into different banks, and use a hash function that can scatter the hash result into
different banks with high probablity, then we can still probe these banks in parallel. )

In the last proposal, indices bits are not extracted from the lowest bits of the page number of each size class,
which causes problem if the low page number bits of small pages are actually page offset bits in larger pages. 
Instead, the index bits are extracted from a static set of bits, which are aligned to the lowest bits of the page
number for the largest size class. This way, the index bits are independent from the size class, which can be 
determined before the size class is known. The drawback of this approach, however, is that for smaller size classes,
adjacent pages are highly likely to be mapped to the same entry, since the index bits are, in fact, higher bits
of their page numbers. This is extremely bad for workloads with spatial locality, where most memory accesses are 
"clustered" to only a few ranges in the virtual address space. In this case, only a few sets will be leveraged,
which will suffer an unacceptablly high level of contention.

The skewed TLB design partially adoptes the second proposal in which the TLB ways are statically divided for different
size classes. For an address X, when its translation entry is to be inserted into the TLB, the TLB controller knows
its size class from the page table walk or from the lower level TLB. Given a TLB design with i ways and j size classes
(assuming i is a multiple of j), we statically partition the TLB into i / j parts (we use P to refer to this value),
and assign a size class to each part in a per-address basis. The paper uses the example of Alpha platform where 
there are four size classes: 8KB, 64KB, 512KB, 4MB. The TLB consists of 8 ways, which is partitioned into 4 parts,
each having two ways. For simplicity of discussion, we name the four partitions P1, P2, P3 and P4. 
Ways are stored in seperated banks such that they can be addressed in parallel as in a conventional set-associative design.
For a given address X, each of the four ways is assigned a size class using a easily computable hash function.
The hash function must satisfy the following two properties. First, given an address X and one of the four size
classes, the hash function should output a partition that dedicates to storing the mapping of the address, if the 
address is indeed of the given size class.
