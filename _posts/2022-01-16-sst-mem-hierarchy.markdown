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

The rest of the source file just defines getters and setters of data members, and method functions for testing various
flags.

### Constants, Macros, and Flags

File `memTypes.h` defines the full set of memory commands, coherence states, and coherence transitions used in the 
memory hierarchy.
The macro `X_CMDS` defines a table of memory commands, with the response command, command class,
command route, write back flag, and the type of the command.
Each row of the table is defined by a macro `X`. According to the exact definition of X, different columns
of the `X_CMDS` table can be extracted.
For example, `enum class Command` is a C++ `enum class` with the body being a list of the memory commands.
In order to define the class, macro `X` is temporarily defined as `#define X(a,b,c,d,e,f,g) a,`, meaning that
it extracts the first argument of macro `X`.
`X_CMDS` is inserted after the definition of `X`, which is replaced by an array of table rows encoded with 
macro `X`, which will simply be replaced by the first macro argument of `X`, i.e., the command itself.

Other constant arrays are defined in an exact same way by extracting different columns from the `X_CMDS` table.
`CommandResponse` defines the response message of each command, and it exacts the second column of the `X_CMDS` table
as the body of the array. If a command is not of the request type, and hence has no corresponding response command,
the response command will be `NULLCMD`.
This array, as well as all arrays covered below, are indexed by the command's `enum class` integer value.
`BasicCommandClassArr` and `CommandClassArr` define basic command classes and command classes, which extract the 
third and the fourth element of the `X_CMDS` table.
Similarly, `CommandRouteByAddress`, `CommandWriteback`, and `MemEventTypeArr` define command route,
command write back flag, and the memory event type, which are extracted from the rest of the table columns.

Coherence states are defined as a table by the macro `STATE_TYPES`, with the first column being the state,
and the second column being the next state.
The `enum` type `State` stores a list of all coherence states, which is defined by extracting the first column
of the `STATE_TYPES` table.

## The Hierarchy Interface

The memory hierarchy in SST does not directly interact with the CPU. Instead, the hierarchy is exposed to the CPU
by an interface class, which selectively exposes a limited set of commands, while encapsulating the implementation
details of the hierarchy within the interface class. 

Memory requests are generated by the CPU in the form of `class SimpleMem::Request` objects, and then given to the 
interface class (which is instanciated as a subcomponent of the CPU, as we will see later) via direct
function calls. The interface class then translates the memory requests into the memory event objects that are 
internally used by the hierarchy, and keeps a mapping between requests and memory event requests/responses.
When a response is received from the hierarchy, the interface class finds the matching request object, and 
generates a response object, before returning that to the CPU via a function call back.

### SimpleMem

`class SimpleMem` is the base class of the memory interface, and it resides in the core part of SST, in file 
`simpleMem.h`. It exposes an interface to the memory hierarchy via 
`class Request` objects, and two simple interface functions: `sendRequest()` and `recvResponse()` (the latter is
only used for polling-based interface, though, while we only cover event-based interface).
`class SimpleMem` and all its derived classes are derived from `class SubComponent`, which cannot be instanciated
independently, but must be loaded into a subcomponent slot of the containing component via the configuration script.

`class Request` is an enclosed class defined within `class SimpleMem`, and it is the object that CPUs use to 
interact with the memory hierarchy.
The object contains high-level memory operation information, such as command, requested addresses (multiple
addresses are supported for, e.g., scatter-gather access patterns), request size (only one uniform size), 
data payload, and some flags (defined as macros beginning with `F_`). 

Each request object also has an `id` field, which stores the globally unique ID generated by atomically incrementing
the ID counter, `main_id`, at object construction time. The `main_id` counter is defined as a static member
of `class SimpleMem`, and is hence globally consistent.
Just like the case with `class MemEventBase`, CPUs and interface objects use the global ID to keep track of 
outstanding memory operations, and to match responses with requests.

Note that the command used by `class Request` differ from the internal commands of the hierarchy defined in 
`memTypes.h`. The interface-level commands are designed for the relatively high-level operations from the
perspective of CPUs, and will be translated to and from the internal command by the implementation of the interface 
class for requests and responses, respectively.

The lifetime of request objects, contrary to the lifetime of memory event objects, span the duration of the memory
operation. Request objects are allocated by the CPU who initiates the memory operation (e.g., in 
`commitReadEvent()`, `commitWriteEvent()`, and `commitFlushEvent()` of `class ArielCore`), and are kept in an internal 
pending operation map of the interface, which are matched against incoming completion notices from the hierarchy. 
When an operation completes, the original request object will be 
retrieved, updated to reflect the completion status of the operation, and sent back to the CPU. The CPU is responsible
for the final destruction of the request after processing it (for example, in `ArielCore::handleEvent()`).

### The Interface Object

The implementation of the interface object in SST's memory hierarchy is defined in files `memHierarchyInterface.h/cc`,
as `class MemHierarchyInterface`. The class is derived from `class SimpleMem`, and hence can be loaded as a 
subcomponent into the component slot.
In the Python configuration file, `class MemHierarchyInterface` is instanciated by calling `setSubComponent()` on the 
CPU component object, with the first argument (slot name) being `memory`, and the second argument being 
`memHierarchy.memInterface`. 

#### Communicating with CPU and the Hierarchy

`class MemHierarchyInterface` communicates with the containing CPU via direct function calls, since it is instanciated
as a subcomponent, and thus no link is required at the CPU side. At the cache-facing side, the interface object
defines a port named `port`, that needs to be connected explicitly to the highest level of the hierarchy
using `connect()` method of the Python link object.
Memory requests generated by the CPUs are given to the interface object by calling its member function 
`sendRequest()` with the `class Request` object as the argument.
Responses and hierarchy-initiated event objects are received by the registered call back function to the link object,
i.e., `handleIncoming()`.
Once an event is received, it is transformed into a `class Request` object, and then delivered to the CPU via a 
registered call back (note that this call back is registered to the hierarchy interface by the CPU, not to the link
object), `recvHandler_`, which is provided as a constructor argument, `handler`.

The CPU may also choose to not register a call back with the interface object, in which case the `handler` argument to
the interface constructor is set to `NULL`. The constructor will then register the receiving link as a polling link,
meaning that messages received at the link will be buffered in a local queue, and must be retrieved explicitly
by the CPU via the interface's method function `recvResponse()`.
We focus on callback-based mechanism in this article.

#### The High-Level Workflow

When a request is generated by the CPU, it will be sent to the hierarchy object by calling member function 
`sendRequest()`. The function first transforms the request into a `class MemEvent` object by calling `createMemEvent()`,
and then keep track of it by storing the unique ID of the newly created memory event in the internal map, `requests_`,
with the value being the original request object.
When a response or a hierarchy-initiated memory event is received on the link of the interface object, the 
call back function `handleIncoming()` is invoked. The handler function first calls `processIncoming()` to
transform the event into a request object, if the event should be delivered to the CPU (there are events that
will not be delivered to the CPU), then a new request object is created, which carries the information of the 
response. The response `class Request` object is eventually delivered to the CPU by calling the CPU-registered
call back function, `recvHandler_`, with the object being the only argument.

### Transforming Requests to MemEvents

What function `createMemEvent()` does is quite straightforward, and does not require much explanation. It first
translates the request command into the memory hierarchy's command, e.g., reads will become `GETS`, and writes
will become `GETX` (but reads will the locked flag set will become `GETSX`). 
Then it allocates a new `class MemEvent` object from the heap, and initializes the object with all necessary
information in order to perform the operation.
Note that the `src_` field of the memory event object is set to the name of the interface object itself, which is
obtained by `getName()` function call into `class BaseComponent`, and both the `dest_` and `rqstr_` is set to the 
`rqstr_` field of the interface object. This field is initialized during the initialization phase, in function
`init()`, the value of which is the identify of the other end of the receiving link. This suggests that the 
`rqstr_` field of the interface object stores the string name of the next hop, which is typically the L1 cache
or the TLB object.

The memory hierarchy also supports custom commands, which carries a command of `CustomCmd` in the request object.
Custom commands are transformed into a memory event object by calling `createCustomEvent()`, and the resulting
memory event object carries a command of `CustomReq`. We do not cover custom command in this article, as the are 
pretty straightforward to implement.

### Transforming MemEvents to Requests

Function `processIncoming()` first attempts to match the memory event object with the request, by obtaining the ID
of the request memory event using `getResponseToID()`, and then querying the map `requests_` that tracks pending
memory operations (the map uses request memory event's ID as key, and maps to the matching 
request `class Request` object).
If the query fails, meaning that the message is initiated by the hierarchy itself, and no corresponding 
request object exists, but the command is `Inv` (external invalidation), then a new request object is created
with the command being `Inv`, and returned to the caller.
Otherwise, if the query succeeds, meaning that the memory event is a response to a previous request, 
the original request object of type `class Request` is then fetched from the pending request map `requests_`,
and updated to reflect the completion of the request by calling `updateRequest()`.
Finally, the request object will be returned to the caller, which is then delivered back to the CPU.
The mapping entry is removed from the internal map, if the request object is retrieved.

Function `updateRequest()` updates the command of the `class Request` object according to the command of the 
response memory event object. Read operations will receive `GetSResp`, which is translated to `ReadResp`.
Writes will receive `GetXResp`, which is translated to `WriteResp`.
CPU-initiated flush will receive `Command::FlushLineResp` on completion, which is translated to 
`SimpleMem::Request::FlushLineResp`.
