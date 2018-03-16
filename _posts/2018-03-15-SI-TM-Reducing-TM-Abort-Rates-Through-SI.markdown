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

![SI-TM MVM architecture]({{ "/static/SI-TM-architecture.png" | prepend: site.baseurl }} "SI-TM MVM"){: width="400px"}
{: align="middle"}

SI-TM relies on a multiversion device called MVM (Multiversioned Memory). On a CMP with private L1 and shared LLC, 
the MVM is put before the LLC as a translation layer. MVM translates physical cache line address and version pair (addr., ver.) 
into a pointer to the versioned storage. The pointer can then be used to probe the shared cache, or, if misses, to
probe main memory. L1 and L2 use the physical address from TLB as the tag. *When a cache line is evicted or when a request
is sent, the message must go through MVM using the physical address and the version in the context register to obtain
the physical address for probing LLC and DRAM. This is somehow awkward, because when invalidation message is received,
there is no backward translation mechanism to invalidate the corresponding cache line in private L1/L2. In addition,
the transaction is not fully virtualized, because now the physically tagged L1/L2 is actually virtually tagged. When
a context switch happens, the speculative cache lines must be flushed or written back.*

*What I did not understand in the above figure is the placement of begin and commit timestamp. Conceptually they belong to
the executing transaction, which should be part of the processor's private context. In the figure it is drawn in the
uncore part of the procssor, implying the begin and end timestamp are shared across processors.*