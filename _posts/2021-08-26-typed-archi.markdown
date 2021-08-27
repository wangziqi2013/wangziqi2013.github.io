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
