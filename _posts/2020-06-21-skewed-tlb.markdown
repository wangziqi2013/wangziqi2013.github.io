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


