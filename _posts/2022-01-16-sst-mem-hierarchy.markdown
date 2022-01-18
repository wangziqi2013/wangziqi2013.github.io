---
layout: post
title:  "Understanding Memory Hierarchy Simulation in SST"
date:   2022-01-16 02:30:00 -0500
categories: article
ontop: false
---

# Memory Hierarchy

## MemEventBase and MemEvent

`class MemEventBase` and `class MemEvent` are the two classes that are used throughout the memory hierarchy to model
message exchange between memory components, and to carry the commands as well as responses.
They are defined in file `memEventBase.h` and `memEvent.h`, respectively. The related constants, macros, such as
memory commands, coherence states, and command classes, are defined separately in `memTypes.h`.
Both classes are derived from the base class `class Event`, meaning that they can be sent over link objects just like
any other event objects. 

### MemEventBase

`class MemEventBase` defines low-level link layer properties of the message, such as 
source and destination names (which, surprisingly, are of `std::string` type) of the current hop, `src_` and `dst_`, 
the original requestor's name (which is also an `std::string`), `rqstr_`, 
the memory command, `cmd_`, and the globally unique event ID, `eventID_`. 
If the message is a response to a previous request, then the ID of the matching request event is stored in 
`responseToID_`, such that the requestor as well as all components on the path can identify the matching request
message when receiving a response.

All memory hierarchy event objects are assigned globally unique IDs by calling `generateUniqueId()`, which is 
defined in the base class, `class Event`. The ID is assigned in member function `setDefaults()`, which is called
by the constructor, meaning that all memory hierarchy event objects carry a valid ID.
Interestingly, `class Event` objects themselves do not define the unique ID, but leave it to the derived class for
generation and storage of the ID.

The `class MemEventBase` object also carries cache flags in `flags_` field, which uses the flag constants defined 
in the same source file that begins with `F_`. These flags indicate special semantics of the message,
such as locked accesses, non-cacheable accesses, etc., and are only used in specific scenarios.

The lifetime of memory event objects is from the sending of the message to the successful processing of the message.
If a new message is to be generated, the old one is freed, after the new message is created based on the contents 
of the old. This way, the memory hierarchy defines the ownership rule for memory event objects: These objects are 
created by the sender of the message via C++ `new` expression, while the receiving end retains the ownership of
the message, once delivered, and is responsible for destroying the messages when they are successfully processed
(destruction can be delayed, if the processing indicates a failure and demands a reattempt later).
In other words, each memory event object only carries information for one hop, from the source to the destination
(which correspond to the `src_` and `dst_` fields).

Member function `setResponse()` of `class MemEventBase` provides a handy shortcut for setting the fields of a 
response message, given an existing event object as the request, the command of which must be of a request 
type in order for this function to work properly (this prerequisite is not checked, though). 
The function simply sets the new message's next hop of destination as the given message's source, and sets the 
source as the destination, meaning that the response message is intended to be sent backwards to the exact same
sender of the given message. 
The `responseToID_` field is also set as the unique global ID of the request event, such that the receiving end 
can match the response with the request.
The `makeResponse()` function simples does slightly more than `setResponse()` by allocating a new event object
as an exact clone of the current one (passing `*this` into the copy constructor),
and then passing the current object as the first argument to `setResponse()`. 
The newly created object is a response event to the current event on which the member function is called.

### MemEvent

`class MemEvent` is a direct derivation of `class MemEventBase`, and an indirect child class of `class Event`. It
inherits all data fields carrying link-level information, and in addition, it also defines high-level operation details,
such as the byte-granularity address of the request, `addr_`, the block-aligned address, `baseAddr_`, 
whether the message contains dirty data, `dirty_`, whether the message is a block eviction, `isEvict_`, and payload
of either a request or a response, `payload_` (which is merely a vector of bytes, `std::vector<uint8_t>`, typedef'ed
as `dataVec`). The object also maintains memory transaction-level control variables, such as the number of retries,
`retries_`, and whether the event is blocked by another pending event on the same address, `blocked_`, 
whether the event is currently being handled by the controller, `inProgress_`, and so on.

`class MemEvent` also defines the `makeResponse()` interface. The argument-less version overrides the method of 
`class MemEventBase`, and it creates a new `class MemEvent` object that is the response to the current one on which
the method is called. Other versions of `makeResponse()` are also available, which creates new event objects using
an explicit `cmd` argument as the command of the new object, or with an unused `state` argument.

## The Hierarchy Interface

