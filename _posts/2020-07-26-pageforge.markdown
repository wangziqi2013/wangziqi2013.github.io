---
layout: paper-summary
title:  "PageForge: A Near-Memory Content-Aware Page-Merging Architecture"
date:   2020-07-26 00:46:00 -0500
categories: paper
paper_title: "PageForge: A Near-Memory Content-Aware Page-Merging Architecture"
paper_link: https://dl.acm.org/doi/10.1145/3123939.3124540
paper_keyword: Page Deduplication; PageForge
paper_year: MICRO 2017
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes PageForge, a hardware assisted page deduplication design which reduces cycle wastage and cache pollution.
Page deduplication has shown its potential in virtualized environments where different virtual machines, though strongly
isolated from each other, may use the same OS image and/or load the same shared library, exhibiting suffcient redundancy
for a deduplication scheme to significantly reduce storage consumption. 

The paper identifies that existing software-based page deduplication schemes have two problems: cycle wastage and cache
pollution. In order to find pages that contain duplicated contents, a background thread needs to continuously monitor 
pages and compare them to find chances for deduplication if they occur. This is a heavy-weight task, which is usually delegated
to a seperate thread on a dedicated core, and has non-negligible cycle overhead. 
In addition, since the background thread must read pages into the cache first before performing comparison. The resulting
cache pollution and bandwidth overhead may also negatively impact performance when the system load is high.
Although non-temporal memory accesses or non-cachable memory type can be employed to minimize the effect of cache
pollution, resource contention, such as convention on MSHRs, and the extra bandwidth imposed on the on-chip network,
still pose challenges for software solutions to solve.

This paper assumes KSM as the baseline software page deduplication scheme. KSM relies on the operation system to specify
one or more memory address ranges, and uses a periodically invoked software thread to identify duplicated pages in these
ranges. Once duplications are found, the pages will be merged by changing the page table entry to point to one of the 
physical pages, and releasing all other identical pages. The page table entries will also be marked as read-only regardless
of the original permission. A copy-on-write will be performed if one of the virtual addresses sharing the same physical
page is written into.
The background thread maintains a sorted binary tree, called the stable tree, for tracking physical pages that have been 
deduplicated. Each node of the binary tree contains the physical number of the page, and sorted property is maintained 
as in a binary search tree. The comparison function is just simple binary comparison on the page content. 
On each iteration of the background thread, the candidate pages in the specified ranges (except those that are already
in the stable tree) are checked against the stable tree one by one, and deduplicated if a match is found. 
If no match can be found, the thread then checks whether the page has been modified since the last time it checks the 
page. To track the modification status, the OS maintains a hash value for each page in the range, which is computed
with the page content, and updated on each iteration of the KSM thread. The old hash value, which is computed in the 
last iteration, will be compared against the new hash value computed in the current iteration, and if they mismatch,
the page is deemed as "volatile", which will be excluded from deduplication for the current iteration. 
For those pages who have not changed since the last iteration, and cannot be matched against an existing deduplicated page,
they will be inserted into an "unstable tree", which is the same type of binary tree as the stable tree, but just tracks
pages that may potentially match other non-duplicated pages. Each candidate page, if they have not been excluded, will 
be checked against the unstable tree as the last step. If a match can be found, then deduplication is performed,
and the underlying physical page is inserted into the stable tree. Otherwise, the candidate page is simply inserted
into the unstable tree for future comparisons.

The paper observes that three important and most resource consuming abstractions of the KSM core algorithm can be implemented 
in hardware. The first is page comparison, which requires nothing more than a parallel comparator for computing the difference
of two pages in binary form, similar to the hardware version of memcmp(). 
The second is tree traversal, which requires a hardware state machine to perform page comparison, and then selects the 
left or right child as the next comparison target based on the result of comparison. The design, however, does not 
implement tree construction for two reasons. First, the complexity of updating red-black trees, which are used for both
stable and unstable trees in KSM, in hardware is too high to be realistic. Second, hardware can only provide a finite
number of node slots, and is difficult to change, while in practice there can be as many pages for deduplication as the 
system administrator wants as long as the overhead is not an issue. Based on the above reasons, the OS still maintains
software copies of the two trees and hash values for individual pages, and only relies on the hardware to perform
read-only operations such as tree traversal and page comparison.

We next introduce the hardware implementation of tree traversal and hash generation as follows. Tree traversal is 
implemented with a state machine as described above, plus a tree representation in hardware, which can represent
a full or a partial binary search tree. Only having partial trees is perfectly fine, since the OS may start from
a root node, only loads the first few levels of the binary search tree, invoke the hardware, and repeat the above
process using the intermediate node the traversal reaches as the new root node. Since binary tree traversal is recursive,
the hardware does not care whether the root node is the real root, or just some intermediate node resulting from
the previous traversal. 

