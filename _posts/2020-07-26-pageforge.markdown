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

**Highlight:**

1. Implementing binary tree traversal with hardware state machines. Recognizing that tree traversal is recursive and highly
   localized, so we could always only use a partial tree to perform traversal.

2. Repurposing per-cache line ECC and combining them together as the hash code of a page

**Questions**

1. The paper mentions that the OS should check back for traversal termination, but did not mention how or when. High frequency
   polling is definitely not advisable. But if the interval is too high, we actually impose a latency overhead of the traversal
   operation.

2. The paper mentions that to avoid the selected page being modified after comparison, the OS should double check whether the
   two pages are identical after setting read-only protection. Should this be performed by hardware? Or the OS invokes the
   memory controller to perform the check?

3. Since the memory controller is able to issue read-shared requests, dirty cache lines will be sent over the bus to the
   memory controller onr receiving such as request. The problem is since the controller does not maintain any cached
   copy, the dirty cache line must always be written back to the DRAM. This introduces non-negligible write back cost,
   which is not evaluated by the paper.

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
The tree is stored in a randomly accessible table called the scan table. Each entry of the scan table consists of 
the physical page number, the index of the left child, and the index of the right child. The first element of the
table is implicitly used as the root of the traversal. Left and right child pointers store the index of the 
left and child node, respectively, in the table. If the node is leaf, or if the child nodes are not in the 
current partial tree due to capacity limit, the pointers will be set to NULL.
Besides, the information of the candidate page is stored in a separate register which includes the candidate
page's physical page number, the hash value, and a few control bits for storing the result of the traversal. 
On invoking the traversal, the hardware state machine reads both the candidate page and the page under comparison, which
is initialized to the first element of the scan table. After both pages are read and comparison results are available, 
the state machine either reads the left child pointer of the current node, if the candidate page is smaller, or 
reads the right child if larger, or terminates the traversal if a match is found. Traversal also terminates when 
a NULL pointer is found. The results are stored in the candidate node's register in the form of status bits and indices
(e.g. the index of the last node of the traversal). The OS should periodically probe the candidate node's register for
the traversal status. If the current traversal has finished, and there are still partial trees, the OS will load
the next few levels from the current node where traversal terminates. Otherwise, a new candidate will be loaded as 
well as the tree, which could be stable or unstable tree, before the next traversal begins.

One of the most important differences is that PageForge is implemented on the memory controller, instead of the on-chip
hierarchy. As a result, if a page is only fetched from the main memory, its content may no longer be up-to-date if
a more recent version exists in the cache hierarchy. To always access up-to-date data, the paper proposes that the memory
controller should also implement a inferior version of the coherence protocol, which, for simplifity, does not maintain 
any cached copy or add extra state to the directory (if there is one), but is able to issue coherence requests for shared
reads. Cache lines in modified state should degrade the state to shared, and send the dirty copy to the memory controller.
On receiving the dirty copy, the controller should first write it back, since the controller itself does not act as 
a cache, and in the meantime use the write back copy to perform comparison.

Note that in general, both false positives and false negatives are acceptable and will not affect correctness in the 
original KSM design. False negatives will simply waste an opportunity for deduplication. False positives, however, 
requires special care, since they are always possible if the page is updated after a comparison. 
The paper suggests that the KSM algorithm will re-check whether the two pages are still identical after setting both of 
them for write protection. If they are not, then a write must have occurred on one of the pages after the comparison, 
which aborts the deduplication attempt.

The paper also proposes a mechanism which enables fast hash value computation leveraging the ECC bits. In a normal ECC-enables
system, each 64-byte cache line has an 8-byte ECC word stored in a seperate memory chip. The ECC bits are computed when 
data is updated, and read out when data is accessed.
The paper observes that there are similarities between ECC bits and hash values: If two cache lines are identical, they
must generate the same ECC bits; If two lines are not indentical, then their ECC bits are likely also not identical, although
false posititives maay occur at a small but non-zero probablity.
PageForge generates the hash value using ECC bits as follows. When a page is accessed by the memory controller, either the
ECC bits of each cache line is read from the 9-th chip, or the ECC can be calculated from the coherence response using
the same ECC circuit that calculates ECC on the normal data path.
The memory controller generates a 32-bit hash value by selecting four pre-determined cache lines in the page, and concatenates 
the lower 8 bits of their ECC.
The hash value will then be stored in the candidate cache register, which can be accessed by the OS.
The OS should still maintain, using software, two versions of hash values from the previous and current iteration.
This hardware assisted hash generation, however, saves the cycles and memory bandwidth that were dedicated to computing a
software hashes. Moreover, software hashes often require reading all or part of the cache lines (e.g. 1KB as in software-based 
KMS). These requests can hardly be reordered for better performance, since these algorithms are implemented with strong 
data dependency. Hardware ECC hashes do not suffer similar problems, since ECC bits are always read or computed by
the memory controller, which can be collected cost-free as the controller reads the page.

