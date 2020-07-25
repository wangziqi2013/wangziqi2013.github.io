---
layout: paper-summary
title:  "The Cache for Compressed Caching in Virtual Memory Systems"
date:   2020-07-24 22:03:00 -0500
categories: paper
paper_title: "The Cache for Compressed Caching in Virtual Memory Systems"
paper_link: https://www.usenix.org/legacy/publications/library/proceedings/usenix01/cfp/wilson/wilson_html/acc.html
paper_keyword: Compression; Memory Compression; WK Compression
paper_year: USENIX ATC 1999
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes compressed page cache for virtual memory systems. The paper appreciates the benefit of page compression
for keeping more active pages in the main memory and thus reducing page fault costs, as oppose to previous works where
page compression has been proved to be not useful unless the machine is equipped with slow or no disks. 
The paper makes two contributions. First, it describes a fast and efficient dictionary-based compression algorithm for
compression data on page granularity, which is tuned to fit into common scenarios of page data layout rather than text.
The second contribution
