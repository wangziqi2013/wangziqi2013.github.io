---
layout: paper-summary
title:  "SI-TM: Reducing Transactional Memory Abort Rates Through Snapshot Isolation"
date:   2018-03-15 12:07:00 -0500
categories: paper
paper_title: "SI-TM: Reducing Transactional Memory Abort Rates Through Snapshot Isolation"
paper_link: https://dl.acm.org/citation.cfm?id=2541952
paper_keyword: SI-TM; Snapshot Isolation; Multiversion CC
paper_year: 2014
rw_set: Not mentioned; Logging?
htm_cd: Lazy, version based
htm_cr: Lazy
version_mgmt: Multiversion
---

This paper proposes a multiversion TM design with weaker snapshot isolation (SI) semantics guarantee. 
Canonical HTM designs usually provide conflict serializable guarantees. One one hand, several snapshot 
isolation specific anomalies make programs written on other HTM platforms non-portable. On the othre hand, 
by omitting read set validation, long reading transactions may suffer from 
less aborts. In addition, less hardware resources are dedicated to maintaining transaction metadata,
as fewer states are needed to validate.

One distinctive feature of SI-TM is the usage of multiversion in HTM. The second feature is timestamp ordering
(T/O) based backward OCC validation (validate with committed transactions). Although these two approaches
to concurrency control are not uncommon in software, in hardware they are relatively rare.

SI-TM relies on a multiversion device called MVM (Multiversioned Memory). On a CMP with L1 private and L2 shared cache, 
the MVM is put before the shared L2. MVM translates physical cache line address and version pair (addr., ver.) 
into a pointer to the versioned storage. The pointer can then be used to probe the shared cache, or, if misses, to
probe main memory.

![SI-TM MVM architecture]({{ "/static/SI-TM-architecture.png" | prepend: site.baseurl }} "SI-TM MVM")