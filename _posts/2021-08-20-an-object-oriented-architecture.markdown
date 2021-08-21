---
layout: paper-summary
title:  "An Object Oriented Architecture"
date:   2021-08-20 06:33:00 -0500
categories: paper
paper_title: "An Object Oriented Architecture"
paper_link: https://dl.acm.org/doi/10.5555/327010.327151
paper_keyword: Object Oriented Architecture; COM
paper_year: ISCA 1985
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. Have a segmented virtual address space, but also also have a size class field in the pointer. Within each
   size class, it is just like a normal segmented address space with same-size segments.
   The size class field determines how the pointer should be interpreted (i.e., how segment ID and offset are
   divided).
   This addressing scheme supports both large and small objects since the segments are variable-sized.
   The paper calls it a "floating-point address", but in fact it is just dividing the flat VA space into
   equally-sized size classes, and adopt conventional segmentation within each size class.

2. Uses a per-process segment descriptor table to translate VA to segment properties (i.e., object properties)
   such as base absolute address, object size and class ID. This is similar to a per-process page table,
   but with additional type information.

3. Virtualize the register file and make them addressable in the absolute address space. Each function invocation
   can therefore have one separate register context.
   Register accesses are no different from memory accesses, but are accelerated with an on-chip context cache,
   which is essentially just a register file.
   Register spilling and restoration is not required.

This paper proposes the Caltech Object Machine (COM) architecture with an object-oriented execution model. 
The architecture aims at improving performance for object-oriented languages, which are typically slower due
to late binding, method resolution, and type safety. On a conventional architecture with flat address space
and type-less memory, these advanced features cause significant slowdowns because there is no intrinsic support
from the hardware. COM addresses these issues with instruction-level late binding, abstract instructions, and 
type-aware memory hierarchy. 

The paper lists three advantages of COM compared with conventional architectures. 
First, the COM architecture is capable of enforcing type safety at instruction level with runtime data types.
This will prevent wrong kind of operations being applied on data, such as trying to execute data
or using the wrong arithmetic operation. On a type-less memory hierarchy, there is no way to check type safety, and 
this must be implemented at software level.
Second, COM supports late-binding, meaning that symbols in the program are resolved to the actual implementations
only before execution based on the input data type. Late-binding can be useful for writing general purpose algorithms 
such as sorting, as the data type handled by the algorithm need not be known at algorithm implementation time. 
Programmes can thus write reusable code with abstracted types, rather than implementing a version of the algorithm for
each data type.
Lastly, COM demonstrates greater extensibility by incorporating programmability into the ISA. The COM ISA can be 
extended at the software level by allowing instruction semantics to be redefined on new data types.
Binaries compiled for COM are forward-compatible and can be reused on data types it was not designed for without 
recompilation.

The COM architecture is designed for object addressing with a virtual address space. 
The virtual address space is segmented, meaning that a virtual address consists of a segment ID and the offset into
the segment. Segments are variable-sized chunks of memory, which can be accessed using the same segment ID and 
different offsets. Each segment holds an individual object at the application level, and different segments are 
not logically related to each other.
One of the greatest challenges of segmented architecture is that the architecture must fulfill two conflicting 
requirements:
On one hand, large number of objects may exist at the same time, indicating a large segment ID field, since each 
object must reside in its own segment. On the other hand, due to the existence of large objects, such as big arrays,
the segment sizes must also be large enough to satisfy the majority of the cases, suggesting large offset fields.
Both goals cannot be easily achieved within a segmented architecture, especially with uniformly sized segments
and fixed-length pointers, as the segment granularity needs to be both large and small.

The COM architecture implements a variable-sized segmented virtual address space to address the above two issues.
With fixed number of bits per pointer, the length of the offset field is determined by an extra "exponent"
field which is also encoded in the pointer. By changing the value of the exponent field, the number of bits
allocated to offset and segment ID will also change accordingly. 
In other words, COM's address space consists of size classes, which are selected by the exponent field, and 
the segments are uniformly sized within each size class just like a normal segmented address space.
The paper suggests that in a 36-bit address space, COM dedicates 5 bits in the virtual address to exponent field,
and the remaining 31 bits are shared by segment ID and the offset.
Virtual addresses are interpreted as having K bits of offset and (31 - K) bits of segment ID, given the exponent
value as K.

Virtual addresses are translated into global absolute addresses before being used. The translation is performed 
by a segment descriptor table, which maps the exponent and segment ID into a base absolute segment address, segment 
length (logical size of the object), and an object class ID.
The translation can be accelerated by a hardware cache which is similar to the conventional TLB.

The absolute address space is shared among all processes, while the virtual address space is per-process, implying
that each process should have its own segment description table, which is similar to a conventional page table.
The COM architecture uses absolute addresses uniformly in all levels of the hierarchy, including the cache, the 
main memory, and even the secondary storage.
The mapping between absolute addresses and physical location at each device is handled by the device itself
(e.g., for a cache it is performed by the tag array), which is not specified by the paper.

COM uses tagged memory, and each word in the absolute address space is accompanied by a 5-bit tag. The per-word 
tag indicates whether the content stored in the word is an integer, a floating point number, an object pointer, or 
some other primitive types. The tag is always transferred across the hierarchy along with data. 

COM's also virtualizes its register file, such that the machine state is also addressable in the absolute address space.
This design choice allows arbitrarily large number of register contexts, since a register context can simply
be allocated by acquiring a 32-word chunk of memory from the absolute address space.
COM assigns each function call instance with its own register context, with 
Argument passing is performed by copying the arguments into the registers of the new context, and value return
is performed by passing a pointer to the callee's register context that points to an object in caller's context.
This design is similar to the concept of "register window" in SPARC, but instead of only supporting a limited 
number of windows, COM supports an infinite number of them due to the virtualization of the contexts.

With a virtualized register file, context access is not any different from ordinary memory accesses. Although, since
register contexts are accessed frequently, and are supposed to be fast, COM is equipped with a context cache 
that is specialized for caching context objects (e.g., the block size is the size of a context). 
This essentially makes the context cache as a de facto on-chip register file.
Register spilling is done naturally as the context cache evicts context entries, and is transparent to the software,
i.e., software does not need to explicitly spill registers to the memory due to register pressure, and can
simply assume there is an unlimited number of contexts, one per function call instance.

Contexts are managed by a few on-chip registers. Allocation is handled with a free list (which is allocated by the
OS from the absolute address space). 
The current and the previous contexts are also tracked by two on-chip registers respectively.
On function invocations, a new context is allocated, and the corresponding on-chip registers are updated to point to 
the new and the previous context, respectively.
Each function instance has a separate context object, meaning that functions can use the full set of architectural 
registers without corrupting states in another instance.

The register context is also type-tagged, and the tag may contain one of the few supported primitive types, or 
the object class ID, if the register stores an object pointer.
When a word is loaded into the register context, the 5-bit tag indicating its type is also loaded. If the word stores
an object pointer, then the class ID, which is obtained from the segment description table, is loaded into the 
register context as well. 

When a register is used as an operand, the class ID or type ID of that register is used to determine the actual 
operation of an instruction.
COM also virtualizes the instruction's opcode, such that an opcode can behave differently for different operand types.
For primitive types, the instructions work as in conventional architectures.
