---
layout: paper-summary
title:  "Compress Object, Not Cache Lines: An Object-Based Compressed Memory Hierarchy"
date:   2020-07-11 01:19:00 -0500
categories: paper
paper_title: "Compress Object, Not Cache Lines: An Object-Based Compressed Memory Hierarchy"
paper_link: https://dl.acm.org/doi/10.1145/3297858.3304006
paper_keyword: Cache; Compression; Object; Hotpads; Zippads; COCO
paper_year: ASPLOS 2019
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Fully associative data placement enabled by Hotpads is convenient for implementing data compression, since compressed
   objects can be placed anywhere without gaps in-between. This reduces both internal and external fragmentation.

2. Tagless lookup, non-unified address space and pointer rewriting are all existing mechanisms in Hotpads. These techniques
   can be leveraged conveniently for data compression as well, since object movement is common in compressed cache 
   architectures (called "compaction", which is usually done within the segmented data array of a cache set). 

3. Using proxy objects whose size is statically determined at compilation time as an extra indirection to avoid massive
   pointer rewrite and copy around.

4. Sacrificing a few bits in the physical address space is fine for most applications since they will not be using
   that many anyway. 
   Also metadata can be stored with a few bits in the pointer value, although this has really narrow applicability 
   since on conventional architectures pointers are not opaque.

**Questions**

1. Although I do appreciate some design aspects (tagless lookup, applying distributed system concepts to cache, fully
   associative data placement) of Hotpads, in general I dislike its design philosophy which is hardly more
   than just over-design and brute-force, ad-hoc addition of components. This paper just make it worse by adding even 
   more ad-hoc components, such as the pointer array for large objects.

2. When overflow occurs (assuming small objects), it is not always necessary to set up to forwarding trunk. If the 
   object is non-canonical in the compressed pad, you just need to change the tag mapping, and that will be all.
   Forwarding trunks are only necessary when the object is canonical, since only pointers to canonical objects are 
   allowed. Since non-canonical object copies in non-L1 pads are always accessed via the tag mapping, not via pointers,
   changing the tag mapping is sufficient to update all paths of accessing the canonical object.

3. Non-canonical objects in the compressed domain cannot have pointers referencing them. The paper should mention that
   these objects must have their metadata bits stored in the per-object tag. Canonical objects are fine since there 
   must be at least one pointer from the upper level for it to be "alive" and not GC'ed.

This paper proposes Zippads and COCO, a compression framework built on an object-based memory hierarchy with object-aware 
compression optimization. The paper begins by identifying a few problems with conventional memory and cache compression 
architectures when applied to object-oriented language programs.
First, these algorithms are often designed and evaluated with SPEC benchmark, which mostly consists of scientific computation 
workloads. These workloads constantly use large arrays of simple data types such as integers, floating point numbers, or 
pointers. Classical compression algorithms work well on these data types, since they only consider redundancy in a small
range in the address space, such as one or a few cache lines. With object oriented languages, most of the working sets
consist of objects, which are laid out in the address space with fields of the same object stored in adjacent addresses. 
Conventional algorithms perform less efficiently on objects, since distinct object fields are often not of the same type, 
and have less dynamic value locality compared with arrays of homogeneous data.
Second, most compressed memory architectures require a mapping structure or some implicit rules for locating the address
of a compressed line, since such lines are not always stored in their uncompressed locations. In the former case, the 
extra storage and memory traffic of the mapping structure may just offset the benefits of main memory compression.
In the latter case, the mapping rule must be statically determined, which tends to make use of memory storage less
efficiently, since a compressed block cannot be placed arbitrarily in the address space.
Lastly, conventional compressed cache designs employ the combination of an over-provisioned tag array and segmented data
array for mapping variably sized compressed blocks in the cache. This organization creates two problems. The first
problem is that blocks are most likely only stored at segment boundaries, at a certain order, with the possibility of 
both internal and external fragmentation. The second problem is that on each cache lookup, more tag addresses and metadata 
have to be read and compared in parallel, consuming more power with a potentially large access latency, which can negatively
impact performance as well.

The paper solves the above issues using three novel techniques. First, Zippads is based on Hotpads, an eccentric 
memory architecture optimized for object semantics. Instead of fetching data in an object-agnostic, aligned 64 byte block format,
Hotpads maintains object boundary and type information directly on hardware, exposing object and pointer semantics
to the memory hierarchy, such that the boundaries of objects can be easily identified. In addition, instead of storing
data in fixed sized blocks, Hotpads manages each level of the cache as a heap, which only grows by incrementing the bump
pointer. Objects can be laied out in the data array compactly without any gap in-between, minimizing internal and external
fragmentation. Compression, therefore, can be applied at object granularity for easy access and compact storage.
The second technique is cross-object compression, which aligns objects of the same type and compresses each field 
independently using delta encoding. Since the same field of different object instances tend to store data of similar
dynamic ranges, this can significantly increase compression ratio than trying to exploiting redundancy between different
fields, which are often of different types and feature different dynamic value ranges. 
The last technique is tagless data addressing in the cache hierarchy, which is achieved by leveraging existing cache 
addressing schemes of Hotpads. Pointers to objects in Hotpads store the hardware address of the tag array that the object
is stored, rather than the backing storage in the flat address space (there is no unified address space, and each cache
level is treated as an independent storage device that maintains its own address space). 
When an object moves in the hierarchy, its hardware address also changes, which necessitates pointer updates in all fields
that hold a pointer to the object. This is achieved by explicitly requesting all upper level caches to scan their data
array and update the pointer value if they contain pointers to the object just moved. Zippads leverage this existing 
mechanism in support of object movement in the hierarchy, and extends it such that object movements within the same 
level is also supported. Pointers in Zippads still use hardware address, which in most cases do not require associative
tag lookups to access the object.

We next describe the operation of Zippads. Zippads assume Hotpads architecture, with lower level of the hierarchy (e.g. 
L3 pads and main memory) compressed for effective size and bandwidth savings, while higher levels are not compressed for 
latency benefits. 
Objects are compressed when they are first evivted from the higher level into compressed domain, and decompressed for 
access when traversing in the opposite direction.
Objects need not be decompressed and recompressed between levels in the compressed domain to save power and bandwidth.
One of the biggest advantage of Hotpads architecture is that objects are not statically mapped to a few possible locations 
in the data array using bits from its address. Instead, object storage is allocated from the end of the data array, which
is maintained as a hardware heap, enabling fully associative data placement. 
When an object is evicted from the last level of the uncompressed pad, two cases may occur. In the first, simpler case,
the object has never reached the compressed level before, implying that the object is canonical. The object is then
compressed by the compression engine, after which storage is allocated at the end of the hardware heap.
In the second case, the object is non-canonical and dirty (otherwise it will just be discarded silently), with the 
possibility that the compressed pad already contains an older, stale version of the same object. In this case, an
associative tag lookup is performed using the non-canonical object's canonical address (stored in the object header)
to determine whether a copy exists in the compressed pad. If negative, the object is compressed and stored just as the
first case. If, however, an older copy already exists, the cache controller should compare the size of the older, compressed
object (which is also stored in the object header, no matter it is canonical or not) with the compressed size of the 
updated object. If the former not smaller, the old object can simply overwrite the previous one, potentially leaving
a gap between the current and the next object, causing external fragmentation. The paper claims that external fragmentation
does not have noticable impact on performance, though. If the latter is larger, the old object copy is then invalidated
by clearing the valid bit for the object, and place the new object at the end of the heap. 
Due to the tagless object lookup protocol, if the object is canonical at the compressed pad, it may still be accessed
via the old hardware location, since Hotpads pointers contain hardware addresses and are used to directly access the 
data array. To avoid existing pointers from being invalidated, a redirection record is stored in the old storage
location of the canonical object. Future references of this object using the old pointer, once seeing this special
record (access circuit should check for the record), should continue to the new hardware location and fetch the object.
Luckily, such redirection capability already exist in Hotpads design. In Hotpads, a redirection record will be written
when a canonical object is evicted to the next level between GCs. This paper just slightly extends redirection
by allowing a canonical object be redirected to another location in the same level.

During GC, the forwarding trunk is treated as invalid object, which will be reclaimed. An entry from the old location holding
the trunk to the post-GC location of the canonical object should be inserted into the renaming table for pointer rewrites.
After GC, all pointers referring to the compressed canonical object should have already been updated to use the new 
location. No access redirection will ever happen until the next relocation.

Large objects, however, cannot be moved around easily in the data array. In addition, Hotpads decompose large objects 
(greater than 64 bytes) into 64 byte sub-objects to avoid over-fetching. Zippads follows this sub-object approach by adding
a software-transparent, implicit proxy object to handle large compressed objects. The proxy object consists of a 
pointer array (which is treated as pointers by Hotpads by setting the pointer bit in the metadata), with each pointer
referencing a compressed sub-object of 64 bytes, incurring a 12.5% storage overhead. Note that since object sizes are 
determined in the compilation time, the size of proxy objects is also static in the runtime, which can be computed from 
the object size in the object header. 
All pointers to the original object should now point to the proxy object. Compressed sub-objects are moved around as 
described above, without causing any massive pointer rewrite during GC and copying large amount of data around. 

The paper did not specify any compression algorithm, although a combination of FPC and BDI is suggested. Both algorithms
require a few metadata bits for the decompressor to recognize the layout. These per-object bits cannot be stored as 
tag array entries since not all objects in Hotpads have a tag array entry. They are also better not stored in a dedicated
metadata area in the main memory, since this will increase the memory footprint and impact performance. The paper proposes
that the per-object bits be added to pointers. Three bits from the 48 bit physical address value are dedicated to compression
metadata. For compressed canonical objects, since they are always accessed with the canonical pointer, the accessing 
circuit should always know such information, and therefore is able to decompress without any problem. For non-canonical
objects in the compressed domain, since no pointer shall be generated for them, their compression metadata must still be
stored in the tag array, which, as pointed out by above discussion, are the only access path for these non-canonical objects.

The paper later proposes COCO, an object-aware compression algorithm leveraging delta encoding between the same field.
It works by comparing objects to be compressed with certain "base objects", computing the delta from the base object,
and storing only delta and a "diff" bit vector as compressed object.
The base object for a certain type is selected as the first object of that type that is evicted into the compressed domain.
A small cache is added to store the base object in uncompressed form when the type ID (stored in the object header) is not 
in the cache yet. For later objects evicted into the compressed domain with the same type ID, the compression circuit 
compares both objects and outputs the compressed object. The compression circuit consists of an array of bytes comparators 
and two shifting registers. The comparators determine which bytes in the incoming object differ from the base object.
Both shifting registers then shift "diff" bits and bytes that do not match respectively. Decompression circult simply
consists of a shifting register and a demultiplexer. The shifting register accepts input from either the base object, if
the "diff" vector indicates a match, or from the compressed stream, if the diff indicates otherwise. Both compression
and decompression circuits are significantly simpler than those in previous designs, since only comparators and 
shifting registers are required.

At the end of the paper, it is suggested that Zippads can be combined with COCO to yield much higher compression ratio,
or be used as a standalone module with FPC + BDI. Even in the latter form, Zippads can still outperform conventional
methods with the same algorithm, due to its compact storage and tagless access path of objects.
