---
layout: paper-summary
title:  "Typed Architectures: Architectural Support for Lightweight Scripting"
date:   2021-08-26 20:44:00 -0500
categories: paper
paper_title: "Typed Architectures: Architectural Support for Lightweight Scripting"
paper_link: https://dl.acm.org/doi/10.1145/3093337.3037726
paper_keyword: Typed Architecture
paper_year: ASPLOS 2017
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlights:**

1. This paper optimizes over the two most common operations: Type ID read/write, and function dispatching for 
   common types. The former can be implemented by providing some sort of programmability using three registers
   (offset, shift, mask), and the latter can be implemented with a lookup table that virtualizes instruction opcode.

2. A typed architecture does not necessarily imply a type tagged address space. In fact, it also works for explicitly
   typed environments such as scripted language interpreters. Just tell the hardware where to find the type tags, and
   it can be loaded/stored with the actual value.



**Comments:**

1. The design seems to assume that the type ID of an object pointer is adjacent to the pointer value itself,
   rather than within the chunk of memory being pointed to (because the type ID address is generated relative to 
   the address of the value to be loaded, not relative to the value itself).
   I wonder to which extend this assumption is true, because, according to my limited understanding of how 
   interpreters are actually implemented, isn't those type IDs typically embedded in the object itself?   

2. The paper did not mention how F/I bits are initialized/spilled with tagged load/store instructions.
   In "code transformation" section it is indeed mentioned that they are initialized from the type tag somehow.
   But what is the generalized semantics of F/I bits and how are they initialized?

3. Tagged stores are more complicated, and it requires a read-modify-write of the word containing the type ID,
   because the type ID should be shifted and OR'ed onto the word, rather than performing a blind write.
   This is significantly more complicated than the paper suggests, because the pipeline controller needs to 
   issue an implicit load to read the value first, then perform shift-mask-OR, and then issue another implicit store.

4. If the lookup table already virtualized opcodes such as xadd, xmul, why do you still need a F/I bit?
   Just initialized the table to something like "I/I/xadd -> integer add", "F/F/xadd -> float add", and problem solved.

This paper proposes Typed Architecture, an enhancement to low-power IoT and embedded processors that enables efficient
type checking and operand dispatching on hardware.
The paper is motivated by the fact that current commercial platforms for low-power applications run scripted languages
such as Lua, Python, or Javascript for their fast deployment capabilities and ease of development.
These languages feature dynamic types and type-based virtual function calls, which require runtime support for type
checking and operand dispatching.
The paper observes that these operations incur huge cycle and power overhead on the platforms where Just-In-Time 
compilation is not practical due to power and hardware resource reasons.

The paper identifies three major sources of type-related overhead in scripting languages.
First, the per-object type ID needs to be read for every object operation, and set in newly created objects. It
takes at least one extra memory read and optionally a few bit level instructions to extract the ID, and these 
instructions cannot be serialized due to data dependency.
Second, type checking is required for every operation between objects, even primitive objects such as integers, 
as every entity is an object in scripted languages. 
Under an interpreted environment, the type check must be explicitly performed by the software interpreter, which 
consumes hardware resources. 
Lastly, operations between objects, including both arithmetics and function invocations, are virtual, meaning that
the actual implementation to be called is not only dependent on the symbol name (or the operator), but also on
the types of the operands. This feature enriches the semantics of operators and function invocations, at the 
cost of extra table lookups for every operation.

To address the above issues, the paper proposes a type-aware architecture where the register file is tagged with types,
and instruction opcodes are virtualized such that the same opcode operates differently on different type combinations.
Each register in the register file is extended with an 8-bit type field, supporting up to 256 possible dynamic types, 
and a one bit F/I flag for indicating whether a floating pointer number or an integer is stored in the register.
The type field of registers are initialized from the per-object type ID when a value or an object pointer is 
loaded from the memory hierarchy.
The design assumes that the type ID is stored in either the same word or an adjacent word of the value being loaded
into the register via load instruction, and provides a general mechanism for loading the type. 
In order to extract the bits for representing the type ID, three registers are used, namely offset, shift, and mask.
The offset register is a two-bit field defining the location of the type ID relative to the value being loaded,
which can be one word before, one word after, in the same word, or do not care. In the last case, the type ID will
not be loaded, and the value is assumed to be untyped.
The shift and mask register define the number of bits to be shifted out from the LSB, and masked out from the MSB, 
respectively, after the word containing the type ID is loaded.
When a tagged memory load operation (tld) is being executed, the pipeline will inject another implicit memory 
load operation using the address indicated by the offset register, if the type ID is not in the same word and is 
not "do not care". Then a shift-and-mask is performed on the word containing the type ID to extract the 8-bit ID, 
which will then be loaded into the destination register's type ID tag together with the value just loaded.
Similarly, tagged memory store operations (tst) will be executed as two stores, one to the word to be written to,
and the other to the word containing the type ID, if the type ID is on a different word than the target word.

Instruction opcodes are virtualized using a lookup table before the ALU stage of the pipeline. 
The lookup table is a small content-addressable memory that uses the type of the two operands as well as the 
opcode itself as the key, and the output is the concrete operation.
The table lookup may produce three possible outcomes: Either both operands are integers, and the operation is 
an integer operation, or both operands are floating pointer numbers, and the operation is an FP operation,
or the types are composite or incompatible (int and float), which requires software involvement to perform
a high-level operation and/or type casts.
In the previous two cases, the operands are dispatched to the integer ALU or FP ALU, respectively, and the 
instruction is executed as a native operation.
In the last case, a software handler is invoked like a function call, which performs the high-level operation 
as indicated by the types, and passes the result to the pipeline on function return.
The addresses of the software handlers are outputs of the lookup table, which are initialized by the interpreter
environment.
To aid software handlers for type checking, the design also provides instructions to access the per-register type ID
field, such that they can also be read and updated by the software.