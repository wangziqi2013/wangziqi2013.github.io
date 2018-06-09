---
layout: paper-summary
title:  "Efficient virtual memory for big memory servers"
date:   2018-06-09 00:34:00 -0500
categories: paper
paper_title: "Efficient virtual memory for big memory servers"
paper_link: https://dl.acm.org/citation.cfm?doid=2485922.2485943
paper_keyword: Direct Segment; Segmentation
paper_year: ISCA 2013
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---   

This paper proposes direct segment, a segmentation based approach to virtual address
translation. The motivation of direct segment is high overhead of Translation Lookaside Buffer (TLB)
lookup on modern big-data machines. On one hand, big-data applications do not require complicated memory 
mapping. On the other hand, existing paging systems manage memory mapping for each 4 KB page separately, 
relying on a TLB to accelerate translation in most cases. The classical paging-based address mapping in this 
regard is inefficient by having both page walk overhead and redundency of memory protection bits. Based on these 
observations, direct segment is designed to eliminate paging overhead with simple hardware changes. We 
elaborate the design in the next few sections.

Long running big data applications, such as memcached or MySQL, demonstrate several memory usage patterns that 
distinguish them from short running interactive programs. First, they normally do not rely on the OS to swap in 
and swap out physical pages to transparently overcommit. Instead, they treat the main memory as a buffer pool/object 
pool, and automatically adjusts its memory usage to the size of the physical memory available in the system. 
Swapping can do very little good here, because big-data applications are not willing to suffer from the extra I/O
overhead bound to swapping. Second, big-data applications typically allocate its workspace memory at startup, and 
then perform memory management by its own. Fine-grained memory management at page granularity is of little use
in this scenario, as external fragmentation is not observable by the OS. Third, the workspace memory of big-data
applications are almost always of readable and writable permission. Per-page protections bits are useful in cases such as 
protecting code segment from being maliciously altered, but there is no way of selectively turning them off for 
the workspace memory area. Overall, we conclude that the current hardware page-level fine grained mapping and protection 
machanism is sufficient, but not in its best shape to deliver high performance for big-data applications.