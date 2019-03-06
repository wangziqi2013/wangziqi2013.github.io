---
layout: paper-summary
title:  "Dual-Page Checkpointing: An Architectural Approach to Efficient Data Persistence for In-Memory Applications"
date:   2019-03-05 21:51:00 -0500
categories: paper
paper_title: "Dual-Page Checkpointing: An Architectural Approach to Efficient Data Persistence for In-Memory Applications"
paper_link: http://grid.hust.edu.cn/wusong/file/taco18.pdf
paper_keyword: NVM; Durability; Checkpointing; Copy-on-Write
paper_year: TACO 2018
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper proposes dual-page checkpointing, a hardware checkpointing scheme based on fine-grained copy-on-write (COW)
with low metadata and storage overhead. The paper identifies the problems of two popular checkpointing schemes, logging
and coarse-grained Copy-on-Write, which we describe as follows. Logging requires the system to duplicate every memory
write to the NVM, one for in-place updates to the home location, another for generating log entries. Excessive NVM writes
are both slow and introduce wearing. Careful optimization may move the slow log entry write out of the critical path,
and only performs logging on the first write during an epoch, but still, the overhead of writing twice is non-negligible.
Page-level Copy-on-Write, on the other hand, never updates data in-place. On an update, the page is first copied to
another location, and then the update is directly applied to the new copy. Since the old copy is intact, even if the 
system crashes halfway before commit, we can still recover to a previous state by simply discarding new pages. On commit,
the updated pages are written back to their home locations, which is done using a system transaction (which itself is 
implemented using undo logging). Page-lavel COW suffers from write amplification, since even a single byte update on
a page requires an entire page to be read and written. Even worse, COW needs two page reads and two page write for every
page updated within an epoch: One read to make the shadow copy during normal operation, one read and write during 
commit to generate the undo log entry, and one final write to flush back the updated shadow page. 

On the other extreme, log-structured NVM system never updates data items in-place. Instead of fixing a home location
for every data item (e.g. virtual pages or objects), log-structured checkpointing designs rely on a mapping table
to relocate newly updated data items to the end of the log. Updated content of data items are also appended to the 
end of the log since NVM favors sequential writes. The problem with log-structured NVM design, however, is that they
penalize every memory access, adding a non-constant overhead to memory operations that access the NVM. In addition,
log-structured designs require an extra garbage collection mechanism, which copies data around and frees stale items
that have been deleted or overwritten, consuming both the bandwidth and cycles. The third problem of log-structured
designs is that they generally require more NVM space than needed, due to the multiversioning nature of the log.

Dual page checkpointing (DPC) attempts to solve all the above problems using a simple mapping scheme built into the memory
controller. Instead of generating log entries and forcing complicated write ordering of log entries, DPC never performs 
in-place updates to older data items (i.e. created by previous epoches) during an epoch. Compared with coarse-grained 
COW, DPC uses bit vectors to maintain dirty and location information, such that pages can actually be managed in a flexible,
per-cache line manner. Compared with log-structured NVM, DPC restricts the possible locations a virtual page can be mapped 
to (similar to page coloring, but the restriction is even more strong), and hence can just use one bit to indicate the 
location of a virtual page. Put them all together, DPC can achieve fast hardware checkpointing with small metadata and 
torage overhead.

The system assumption of DPC is as follows. DRAM and NVM are attached to the memory bus, which allows byte level addressing
for both devices. This paper, in particular, uses DRAM as an L4 cache for the NVM, and applications have no capability to
directly address the DRAM. Global execution is divided into epoches, which are basic units of recovery. If the system
crashes within an epoch, we can always restore the system state to the previous epoch, which is a consistent snapshot 
of the entire system at some point of execution. The paper also assumes that global corrdination exists to synchronize all
processors at a checkpoint, such that processors agree to stop, drain their volatile queues and buffers (e.g. store queue
and instruction window), and write out the on-chip execution context. 

DPC extends the memory controller with a hadrware mapping table which decides the physical location of a page when it is 
accessed from upper level components. In DPC, a virtual page can only be mapped to two locations: One is the physical 
address obtained via MMU address translation, called its "home page"; another is a "derived page", which sits in a special
NVM area allocated by the Operating System at startup time. Given the size of the mapping table as S, at startup time,
the OS must allocate S consecutive pages from the NVM as the derived page area, and inform the memory controller of the 
beginning of the area. The i-th entry of the table records the address mapping for page i of the derived area. There are 
four fields for each entry. The first field records the home page address of the derived page. An associative search is 
performed for every memory operation from upper levels. If there is a hit, then we use the information stored in the 
entry to decide next step operations. Otherwise, a new entry is created if the upper level operation is a write.
The second and third fields are two bit vectors, the length of which is the number of cache lines in the page. Each bit
in the bit vector describes the property of the cache line on the corresponding offset. The first bit vector is cache line 
position bit vector (CPBV). If the bit is set, then the clean version of the cache line (i.e. versions created by a 
previous epoch) is in derived page. Otherwise it is in its home page. The second bit vector is dirty bit vector (DBV).
If a bit is set, then there exists a dirty version of the line written by the current epoch. This dirty version will 
be written back to the NVM and become the clean version for future epoches. The last field is a valid bit indicating 
whether the entry is being used or not. If DRAM is used as L4 cache, necessary hardware components are also added
to support it. Addresses from the L4 cache are physical addresses after MMU translation as in processor caches.

The normal operation is described as follows. On system initialization, all entries in the mapping table are invalidated,
and data is only stored in the home address. Load and store instructions are executed as usual if they hit the first four 
levels of the cache. On an L4 cache miss, the mapping table is consulted using the page address. If the operation is read, 
and no entry exists for the page address, by default all cache lines in the page is stored on its home address, and the 
memory controller fulfills the request by issuing a NVM read request to the cache line's home address. If, however, that an 
entry exists, then the memory controller takes the XOR of the CPBV and the DBV bit of the line to determine the next step.
If the XOR result is one, then a read request is issued using the cache line address calculated from the derived page address. 
Note that since there is a one-to-one correspondence between mapping table entries and derived pages, the address of the 
derived page can be generated given the index of the entry that is hit. Otherwise, if XOR outputs zero, the home address
of the cache line is read, because either the clean data is in derived page, and the current epoch has written dirty
data, or clean data is in the home page, and the current epoch has not written anything.