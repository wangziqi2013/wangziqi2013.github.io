---
layout: paper-summary
title:  "Energy Efficient Address Translation"
date:   2018-06-19 00:40:00 -0500
categories: paper
paper_title: "Energy Efficient Address Translation"
paper_link: https://ieeexplore.ieee.org/document/7446100/
paper_keyword: TLB; Redundant Memory Mapping; Segmentation; RMM; Lite
paper_year: HPCA 2016
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

Translation Lookaside Buffer (TLB) can become a significant source of heat and consumer of power in a 
system. Two types of energy usage are recognized. The first is static energy, which is a consequence of 
page walks and longer execution times due to TLB misses. The second is dynamic energy, which is the energy
consumed by the TLB circuit itself. Techniques that optimize TLB's miss ratio can reduce static energy by
having less page walk and execution time, decreasing the power consumption of the TLB. On the other hand, 
the dynamic energy may increase as a result of more complicated hardware.

This paper aims at optimizing the dynamic energy consumption of TLB by disabling ways if they are hardly
beneficial to performance. The optimization is based on several observations on modern TLBs. First, current
implementations of TLBs on commercial processors have several levels, together forming a hierarchy. In the 
hierarchy, L1 TLB is accessed most frequently, and is responsible for most of the power consumption. TLBs are 
usually organized in a way similar to caches, where the translation takes place in two steps. The first step
is to use the index bits extracted from the address to locate the set. Then a tag comparison is performed in the 
set to locate the entry if it exists, or signal a miss. Tag search and comparison is relatively expensive,
because all tags are read and compared against the input address. In addition, to increase lookup locality,
data TLB and instruction TLB are two separate structures. Second, 2MB and 1GB huge page support decreases 
static energy, because they extend the range of the TLB, and hence TLB miss ratio decreases. With the 
introduction of separate TLB for different size classes, however, the dynamic energy increases, because multiple
TLBs must be activated and searched in parallel. This is largely unnecessary since size classes are not distributed
evenly among TLBs. One solution is to simply disable the TLB of a certain size class, if the TLB caches zero entry.
An alternative to separate TLBs for size classes is to use a unified, fully associative TLB for all size classes.
The TLB controller compares not only tags but also page sizes stored with the tag. Fully associative TLBs are 
even more power hungry, because all entries are activated at tag comparison time. Although the paper implicitly
assumes a set-associative TLB, as we shall see later, the design in this paper extends naturally to fully associative 
TLBs.

In order to identify the optimal number of ways in a set-associative TLB, the paper proposes Lite, a mechanism 
for tracking way usages in TLB. For an N-way set-associative TLB organization, Lite adds (log(N) + 1) counters,
the width of which is not mentioned. We assume that N is a power of two, which is almost always the case with
modern TLBs. Lite implicitly assumes that the TLB maintains replacement information for every entry, perhaps
for implementing the replacement algorithm. All counters are initialized to zero on initialization and reset. 
On a TLB hit, the distance from the last hit on the same way is calculated using the LRU position. If the position 
is between N and (N / 2), then we know if we disable half of the ways under the current configuration, then the 
access will result in a miss. The miss counter #1 for disabling half of the ways are hence incremented. Similarly,
if the LRU position is between (N / 2) and (N / 4), miss counter #2 will be incremented, and so on. To the end,
if the LRU position is 0, which means that the same way was hit in the last access, then miss counter #(log(N) + 1)
is incremented, which measures the number of misses on this way if TLB were entirely disabled. Two extra counters 
are needed also. One for recording the number of TLB misses in the current interval, and another for recording 
the number of cache misses in the previous interval. We cover the details in the next paragraph.

The execution is divided into intervals. In each interval, Lite monitors TLB misses using the TLB miss counter. 
At the end of the interval, it uses the individual way miss counters to estimate the increase in TLB misses if 
half of the ways are disabled. If the increase is not significant, e.g. if stays below a threshold, then half of 
the ways are disabled. Disabled ways no longer store tags and PTEs. Since the TLB is a read-only structure, no
information is needed to write back when disabling ways (Note: I doubt this, becase the dirty bit should be written 
back to inform the OS of a dirty page). The current interval miss counter is copied to the previous interval miss 
counter at the end of the interval. 
