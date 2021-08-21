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
