---
layout: post
title:  "Understanding Memory Hierarchy Simulation in SST"
date:   2022-01-16 02:30:00 -0500
categories: article
ontop: false
---

**Notes:**

1. In this article, we make a strict distinction between the term "initialization" and "construction". "Initialization"
refers to the operations performed in function `init()`, which will be called after object construction, and it mainly
performs runtime configuration or parameter exchange between components.
"Construction", on the other hand, refers to operations performed within object constructors, which happens before
initialization. 
The term "initialize", however, are used interchangeably, and the exact meaning can be deduced from the context
(e.g., if we are talking about "initializing a data member" within the section ob object construction, then it
is obvious that "initialize" here means construction operations).

# Memory Hierarchy

## Memory Event Objects

`class MemEventBase` and `class MemEvent` are the two classes that are used throughout the memory hierarchy to model
message exchange between memory components, and to carry the commands as well as responses.
They are defined in file `memEventBase.h` and `memEvent.h`, respectively. The related constants, macros, such as
memory commands, coherence states, and command classes, are defined separately in `memTypes.h`.
Both classes are derived from the base class `class Event`, meaning that they can be sent over link objects just like
any other event objects. 

During initialization in which runtime configuration (such as topology learning) and parameter exchange, 
another type of event objects are passed around, which is of type `class MemEventInit`, or its derived classes.
These objects carry initialize-related information, and are only exchanged during the initialization stage.

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

### MemEventInit and Its Derived Classes

`class MemEventInit` is only used during initialization. The class defines its own set of commands of type 
`enum class InitCommand`, and stores the command in data member `initCmd_`. 
The initialization command can only be one of the four values: `Region`, `Data`, `Coherence`, and `Endpoint`.
The class inherits from `class MemEventBase`, and it can be sent over the memory hierarchy just like other event 
objects, although this only happens during initialization, and the message is received with polling, rather than
with function call backs.
The base class's command is always set to `NULLCMD`.

Three classes inherit from `class MemEventInit`, namely, `class MemEventInitCoherence`, `class MemEventInitEndpoint`, 
and `class MemEventInitRegion`. As the name suggests, they carry the command `Coherence`, `Endpoint`, and `Region`,
respectively, as well as the information related with these matters. We, however, postpone the discussion of 
each specific event type until the section that they are used with a context. 

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
`rqstr_` field of the interface object. This field is initialized in function
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

## Cache: Array, Replacement, and Hash

The next big topic is the cache, which is the central component of SST's memory hierarchy. 
SST decouples the organization, operation, and coherence aspects of a cache, and makes them into three 
largely independent parts.
In this section, we focus on cache organization, which includes the tag array, the replacement algorithm, and hash 
functions.

### The Cache Tag Array

#### Tag Array Operations

The cache tag array is defined as `class CacheArray`, in file `cacheArray.h`. The cache array class does not 
specify the exact contents of the tag. Instead, the class has one template argument `T` for specifying the type that 
holds per-block tag contents. The tag array object is initialized with cache layout information, such as 
the number of ways (associativity), the cache size (in the number of blocks), and the block size. 
The number of sets is also derived from the above information.
Tag objects are stored in data member `lines_`, which is simply a vector of type `T` objects. 
Blocks (in fact, tags) are uniquely identified using their indexes into the `lines_` vector. 
Hash functions for mapping addresses to set indexes and replacement algorithms that selects a victim block
on insert eviction are also given as constructor arguments. The implementation of these two are also decoupled
from the tag array, and they can be loaded as subcomponents into slot `hash` and `replacement`
(of `class Cache`, not `class CacheArray`), respectively, using the Python configuration file.
Note that both `hash` and `replacement` are just regular data members of `class CacheArray`, and they 
are supposed to be initialized and loaded into the subcomponent slots by the containing class, and then
passed to `class CacheArray` as constructor arguments.

The tag array object also explicitly maintains replacement information of each tag entry in its data member
`rInfo`. `rInfo` is maintained as a mapping structure, with the set number being the key, and type 
`std::vector<ReplacementInfo *>` objects being the value.
Value objects of `rInfo` represent per-set replacement information, and each element of the vector corresponds to 
a tag entry within the set.
The vector's element data type `class ReplacementInfo` is an opaque type exposed by the replacement 
algorithm module, and stores per-entry replacement information, which we discuss later.
Tag entries of type `T` is also supposed to implement a method, `getReplacementInfo()`, which, when invoked,
returns the `class ReplacementInfo` object of that tag entry.

The tag array also implements several standard routines for lookup and replacement.
Method `lookup()` just looks up a particular set based on the provided address, and returns a type `T` pointer as 
a result, if the lookup hits, or NULL, if it misses.
It also takes an argument on whether to update the LRU information of the hit entry, which is performed by 
calling `update()` on the replacement manager with the `class ReplacementInfo` object of the entry.

Method `findReplacementCandidate()` returns the tag entry object to replace within the set, but does not actually
replace it. This function is implemented by merely calling replacement manager's `findBestCandidate()` with the 
set's `class ReplacementInfo` vector, which is maintained by `rInfo` as we have discussed above.

Method `replace()` just invalidates an existing entry plus its replacement info (by calling `replaced()` into the 
replacement manager), and sets a new address to the entry. Method `deallocate()` simply invalidates an entry and 
its replacement information.

Note that the cache tag array is not initialized in the cache constructor. Instead, it is initialized by the coherence
controller, which selects a tag type (template argument `T`) from those defined in file `lineTypes.h`.

#### Cache Tag Types

File `lineTypes.h` defines several tag entry types that can be passed to `class CacheArray` as the template
argument. The file defines three base classes, from which inherited classes are created to represent different 
tag contents.

Base class `class DirectoryLine` defines tag entries that only contain coherence states, but not data.
It is supposed to be used as directory cache's tag entries. The base class contains the block address for which
coherence states are maintained, the state of the block at the current level, a list of sharers in the 
form of a vector of `std::string` objects, and the identity of the exclusive owner in the form of an `std::string`.
As mentioned earlier, the base class also carries replacement information in data member `CoherenceReplacementInfo`.

`class DirectoryLine` also carries a data member, `lastSendTimestamp_`, that is not used for functional simulation,
but to emulate the timing of tag access. This data member remembers the last time (in local object time) the 
tag is accessed, and new accesses to the tag can only be made after this time point. 
This data member implements a miniature queuing simulation: If the `lastSendTimestamp_` value is T1, and an access
to the block is made at time T2, then if T1 > T2, the access at time T2 can only be performed at T1, resulting in the
tag being actually accessed at T1, and the value of T1 is updated to T1 + t where t is the access latency.
If, on the other hand, T2 > T1, then when the access at time T2 happens, the tag entry is not under some prior
operation, meaning that it can be accessed immediately at time T2. The value is updated to T2 + t, which is the 
time the entry will be free for access again in the future. 

Note that this queuing simulation only handles in-order requests, i.e., the accesses time T2 must be a non-decreasing
sequence. As we will see later in the coherence controller section, this property is trivially guaranteed by the cache 
controller processing memory events at a tick-by-tick manner.
This is also the part where SST does not strictly follow the principles of DES: 
Theoretically speaking, a component being simulated by DES
shall only remember the state at the current cycle, and state changes at a future cycle shall be implemented 
by enqueuing an event that updates the state at the future cycle. 
The cache hierarchy designers abandons this idea, due to the overhead it takes to enqueue a trivial state change
object (i.e., changing the state of the block from busy to free), and just uses a variable to remember a future state 
change. 

`class DirectoryLine` also implements several getter and setter functions to query and update the coherence information.
Specifically, caller can add or remove sharers, query whether a particular cache is a sharer, or whether there is
any sharer at all.
In addition, the owner can be set or removed, and the coherence state can be changed to one of the four states.
The timestamp, although not being part of the functional coherence states, can also be set or obtained by calling
the member functions.

`class DataLine` implements a tag entry that contains only data, which is stored as a vector of bytes in
data member `data_`, and a pointer to `class DirectoryLine` object, in data member `tag_`.

`class CacheLine` implements a tag entry that contains both data, as a vector of bytes, and a coherence state 
variable, as data member `state_`. There is neither sharer nor owner information stored, suggesting that this
class can only be used in private caches.
In addition, this base class does not have replacement information, and method `getReplacementInfo()` is a pure
function, making the class a pure abstract class that cannot be instanciated as well.

`class L1CacheLine` is derived from `class CacheLine`, and it adds some additional information to support
more complicated operations, such as LL/SC, locked/atomic instructions, and so on. It also adds an 
`class ReplacementInfo` object and `getReplacementInfo()` method.
Since LL/SC and locked instructions are only seen by the L1 cache, it is suggested that this type of tags is 
most likely used for L1 caches.

`class SharedCacheLine` is also derived from `class CacheLine`, and it adds sharers and owner information
just as those in `class DirectoryLine`. It also contains a `class CoherenceReplacementInfo` object for 
replacement. Since there is no LL/SC and locked/atomic instruction support, we can conclude that this type of
tag is used for lower-level shared caches. 

`class PrivateCacheLine`, like the previous two, also derive from `class CacheLine`. As the name suggests, it is
used on private, non-L1 caches. There is no LL/SC and locked/atomic instruction support. 
The only additional information it has are two boolean flags that reflect the status of the block in the 
current cache: `owned`, and `shared`. It also contains a `class CoherenceReplacementInfo` object.
The `owned` and `shared` flags are kept consistent with the two flags within the `class CoherenceReplacementInfo` 
object, the meaning of which will be explained below.

### Replacement Manager

#### Replacement Information

The memory hierarchy provides several flavors of the replacement manager, which are contained in file 
`replacementManager.h`. This file also defines two extra classes: `class ReplacementInfo` and 
`class CoherenceReplacementInfo`, which must be included in tag array entries, and obtainable by calling 
`getReplacementInfo()` on these entries (i.e., the type `T` argument of `class cacheArray`).
Both classes store the information that is necessary to make a replacement decision within a set.

`class ReplacementInfo` stores the index of the corresponding tag entry in data field `index` 
(this is a duplication of the index field
of tag entries, but is also necessary, since the replacement manager has no idea of the tag entry),
and the coherence state of the tag in data field `state`. 
The state need not precisely reflect the actual coherence protocol, and could just be a rough approximation,
such as `I`/Non-`I`.
`class CoherenceReplacementInfo` inherits from `class ReplacementInfo`, and it stores more detailed 
information about the coherence state, i.e., `owned` boolean flag to indicate whether the tag is owned by
the current cache, and `shared` flag to indicate whether upper level caches may also have a copy of the same block.
Replacement decisions can hence prioritize certain lines over the others based on their detailed coherence status.

#### Replacement Algorithm

All replacement algorithms inherit from the base class, `class ReplacementPolicy`, which itself is derived
from `class SubComponent`, and therefore must be instanciated into the slot of its containing component
in the Python configuration file.
The class is pure abstract, and only serves the purposes of specifying the exposed interface of the replacement 
algorithm: `update()`, `replaced()`, `getBestCandidate()`, and `findBestCandidate()`. As we have seen above,
the cache tag array calls these methods to implement block replacement and invalidation.

`class LRU` is an implementation of ideal LRU replacement algorithm. The class constructor takes the total number of 
blocks in the cache, and the number of ways (which is not used, though), and initializes an internal
vector, `array`, which stores per-tag LRU counter. Note that `class LRU` does not rely on the per-tag 
`class ReplacementPolicy` objects to store the LRU counter, as the counter is not defined in that class.
The class also maintains a global LRU counter, which is incremented every time the counter of a tag is updated,
and the before value of the global counter is assigned to the tag's counter, as can be seen in `update()`.

The `findBestCandidate()` method of `class LRU` takes a vector of `class ReplacementInfo` objects, which correspond
to tag entries of the set on which the replacement is being performed, and searches for the entry with either
`I` state, or the minimal value of the LRU counters tracked by `array` 
(if none of the entry is in `I` state), as the LRU entry.
The index of the LRU entry is stored in data member `bestCandidate`, and is also returned by the method.
Method `getBestCandidate` simply returns the `bestCandidate` value.

Note that the comment block on top of `findBestCandidate()` in the source code describes the function incorrectly
(up to version 11.1.0, which is the reference version this article assumes), 
and it seems that the developers copy-pasted it from that of `class LRUOpt`. A mistake on their part!

`class LRUOpt` implements an optimized version of LRU, which not only takes LRU counter values into consideration,
but also gives priority to entries with a particular state. To elaborate: The algorithm aims at minimizing 
cache blocks that will likely be used and/or will incur larger overhead if evicted. The heuristics is as follows.
First, invalid tag entries always have the highest priority, i.e., just the same as LRU.
Second, if a block is shared by upper level caches, the block will also be 
given higher priority than those that do not, as evicting the block will incur extra invalidations to the 
sharers to maintain inclusiveness. 
Next, if a block is owned by the cache, then ownership must not be given up, since ownership typically indicates
an intention to write and/or dirty blocks.
Tag entries that satisfy none of the above criteria has the lowest priority.

To establish the relation between tag entries according to the prioritization rule described above, `class LRUOpt`
defines a helper class, `struct Rank`, that enables comparisons between tag entries using the mentioned criteria.
In method `findBestCandidate()`, each element of `rInfo` is used to construct a `struct Rank` object by copying the
`state`, `owned`, and `shared` members from the `class CoherenceReplacementInfo` object to `struct Rank`'s fields
with the same name, and copying the timestamp value of these entries from `array` to `struct Rank`'s `timestamp` 
member. 
Then a loop that is similar to the one in `class LRU` is executed to find the smallest `struct Rank` object, and its
corresponding tag entry. `struct Rank` objects are compared based on the prioritization rule: For any two entries in
a comparison, the `I` state entry is always smaller than non-`I` state entries (in the current source code, 
this check is performed outside of `struct Rank`, but it could also be made otherwise); 
shared entries are always smaller than non-shared entries; Owned entries are always smaller than non-owned entries. 
At last, if the ordering still cannot be determined between the two entries, the LRU timestamp is used for final
arbitration, which will never result in a tie.

### Hash Functions

Hash functions are another class of subcomponent that `class CacheArray` uses, which are defined in file `hash.h`.
The pure, abstract base class, `class HashFunction`, exposes a single method `hash()`, which, given an ID and an
address, returns a hash value. In practice, `class CacheArray` always calls `hash()` with the ID being zero, and the 
address being the address of the block.

Three hash function implementations are provided, all of which inherit from `class HashFunction`. 
`class NoHashFunction` does not perform any hashing, and simply returns the original value unchanged.
`class LinearHashFunction` performs a linear transformation of the input value `x` using the formula 
`1103515245 * x + 12345`, and it ignores the ID argument.
`class XorHashFunction` XORs every byte of the input value with the higher byte, except the last byte, which 
is unchanged. It ignores the ID argument as well.

## Cache: Construction and Controller Operation

This section focuses on cache object's construction and high-level event processing operations that do not involve 
coherence (which we simply just treat as a black box). 
We mainly cover the trunk of the cache object's operation logic, and largely ignore minor details such that
debugging, statistics, prefetching, and so on (and they are pretty straightforward once the cache operations 
are made clear).

### Memory Links

Cache objects are not always connected by point-to-point regular links of type `class Link`. 
Instead, they are connected by `class MemLink` 
objects or its derivations, which may provide some routing capabilities based on address ranges and interleaving. 
In this section, we mainly focus on `class MemLink` itself, which still provides the abstraction of a point-to-point 
communication link, and is simply just a wrapping layer over `class Link`.

#### Memory Link Operations

`class MemLink` is defined in file `memLink.h/cc`, which itself is derived from `class MemLinkBase`, defined in
file `memLinkBase.h`. `class MemLinkBase` is derived from `class SubComponent`, meaning that it must be loaded
into a containing component's slot. `class MemLinkBase` contains a call back function as data member, 
`recvHandler`, which is called in method `recvNotify()`. 
The call back function must be set after the construction of the object (or its derivations) by calling 
`setRecvHandler()`, with a caller-provided standard functor object for `class Event`.
The object also contains a `struct EndpointInfo` data object, but 
`class MemLink` does not leverage the endpoint, and hence we exclude this from our discussion.

`class MemLink` wraps a linked object as its data member, `link`. The link is initialized and registered to SST's
global link map in `class MemLink`'s constructor, with the port name given in argument `params`, and the 
receiving call back function being `recvNotify()`, which is a member function in `class MemLinkBase`, as we have
seen above. `class MemLink` also exposes a `send()` method, which does exactly what a `send()` on link object does,
and in fact, the wrapper function just calls `send()` on the `link` member.

The net effect of using `class MemLink` is that, after construction and setting the external receiving handler,
a `send()` method call on the memory link object will send an event object through the link. A received message
will first invoke the internal method `recvNotify()`, which in turn calls `recvHandler` with the received event
object, passing the object to the external handler. 
We conclude, therefore, that the `class MemLink` object alone is merely a wrapped link object with identical 
semantics. 

#### End Point Information

Each memory link object derived from `class MemLinkBase` has a type `struct EndpointInfo` data member, `info`,
which stores the end point information of the memory link. 
The `struct EndpointInfo` object contains a string object, `name`, which is set to the identity of the component
that the memory link object belongs to by calling `getParentComponentName()` in the base class constructor 
(derived classes may modify it, but `class MemLink` does not).
The `addr` and `id` fields are the routing address for on-chip routing, and the context-specific ID of the link.
For `class MemLink`, both fields are set to zero, and is not used.
The `region` field is of type `class MemRegion`, defined in file `memTypes.h`, and it describes a memory region
in the from of start address, end address, interleave size, and interleave step.
Region information of a memory link can be specified via the component, but for point-to-point `class MemLink`, 
the region is just set to `[0, -1UL]` without any interleaving, covering the entire address space.

`class MemLink` also maintains information about the other end of the memory link, i.e., its
immediate neighbor, as well as all reachable end points from its immediate neighbor.
The former is stored in data members `remotes`, while the latter in data member `endpoints`.
Both members are of type `std::set<EndpointInfo>`, and can be updated by calling `addRemote()` and `addEndpoint()`,
respectively, which usually happens at initialization time. 
Besides, data member `remoteNames` stores the set of string names for each `struct EndpointInfo` object in `remotes`.
This structure is used to quickly decide whether an immediate neighbor is reachable via the current link in
method `isReachable()`.
Note that for `class MemLink`, since it is a direct point-to-point link, there can be only
a single remote end point, and hence the set `remotes` and `remoteNames` is always of size one.

`class MemLink` exposes a few interface functions for querying the remote and endpoint information.
Method `findTargetDestination()` returns the name (which is used as a global identifier) of the component
whose address region contains the given address. 
It can be regarded as a simple routing function which, given the address, selects the next hop destination
from all registered destinations tracked by `remotes`.
Method `getTargetDestination()` is identical to `findTargetDestination()`, except that, if the next hop
destination could not be found because no region contains the given address, it prints an error message
and a list of known destinations to assist debugging.

#### Memory Link Initialization

During initialization, `class MemLink` objects that are connected together exchange their identities, and register 
each other in their `remotes` structure. 
This happens in `init()` function, which is called during first stage initialization.
Recall that the first stage initialization happens globally by the simulator main function iteratively 
calling `init()` on all components (in the case of link objects, their `init()` is called by the 
containing component's `init()`), with the argument (`phase` in `class MemLink`'s `init()` function) 
being the current iteration number.
In the first iteration (where `phase` is zero), the `class MemLink` object creates an initialization
message of type `class MemEventInitRegion`, and sends it over the link by calling `sendInitData()` on
the link object. Note that the send and receive function during the initialization stage are polling-based,
meaning that the receiving end must explicitly call `recvInitData()` in order to read messages. 
As we have seen in earlier sections, the `class MemEventInitRegion` type is defined in `memEventBase.h`, 
and is derived from `class MemEventInit`, which itself is derived from `class MemEventBase`.
The initialization message carries the `name` and `region` values in the current `info` object, with the 
event command being `InitCommand::Region` (set implicitly in the event object's constructor).
This happens on the first iteration at both ends of the `class MemLink` connection.

Then, at later iterations, the `init()` function simply listens on the link for initialization messages
from the other end. This is implemented as a `while()` loop that calls `recvInitData()` repeatedly until
the receive queue is empty. For each event, the command is inspected.
If the command is `Region`, then the link object itself processes the event by creating a `struct EndpointInfo`
object with information contained in the message, and insert the object into its own data member `remotes`.
The event object is not used anywhere else as it is destroyed right in the loop.

If the command is `Endpoint`, then the message is cast into type `class MemEventInitEndpoint` (also defined in
`memEventBase.h`), and the end point information carried by the message is added into data member `endpoints`
using `addEndpoint()`, meaning that this message contains a list of objects that are reachable from the other
end of the memory link.
One thing that differs from the handling of `Region` command is that, the `Endpoint` command event is not destroyed
in the loop. Instead, it is added to the data member, `initReceiveQ`, such that the message can also be read
by its containing component during initialization.
The memory link object provides such an interface, namely, `recvInitData()`, for the containing component to read
event objects that are added into `initReceiveQ`. Correspondingly, the containing component may also send
initializing messages via the memory link by calling `sendInitData()` on the link object, the implementation
of which is simply wrapping `sendInitData()` of `class Link`.

Event objects with unknown commands are just inserted into `initReceiveQ`, such that the containing component
may read them in their `init()` functions. 

### Cache Object Construction

#### High-Level Construction Workflow

Contrary to most source files in SST, the cache, due to its code size and complexity, is divided into several 
source files
that do not follow the naming convention, making the source tree hard to navigate for beginners.
File `cacheFactory.cc` contains the cache object constructor. File `cacheController.h/cc` contains the class definition
and implementation of event processing. Certain method names are rather misleading, such as `createCacheArray()`,
which only computes the cache array parameters, and does not have anything to do with the actual 
creation of cache arrays. In fact, `class CacheArray` is not even a data member of the cache. Instead, it is 
contained in the coherence controller, and is initialized along with the coherence protocol (i.e., different 
coherence protocol options may initialize cache arrays differently).

The cache object's constructor is defined in file `cacheFactory.cc`. It first reads cache block size and the number
of banks, and stores them in data member `lineSize_` and `banked_`, respectively. 
Data member `bankStatus_`, which is a vector of booleans tracking whether a particular bank has been active in
an event processing cycle, is also initialized by reserving elements, the number of which 
equals the value of `banked_`.

The constructor then calls `createCacheArray()` to compute the parameters of the cache tag array, specifically, the 
number of blocks in the cache. As a result, the function inserts the key `lines` with the string representing the 
number of blocks into the param object for future use.

The cache is registered to the global clock in the method `createClock()`, which is called after `createCacheArray()`.
The method registers the cache with a tick frequency read from parameter key `cache_frequency`, and the 
handler being the method `clockTick()`. 

Next, the constructor reads the number of requests that can be processed per cycle into data member 
`maxRequestsPerCycle_`. At last, the constructor initializes the cache links with other components by calling
`configureLinks()`, initializes the coherence controller (and the tag array) by calling `createCoherenceManager()`,
and registers statistics using `registerStatistics()`.
One thing to note is that the coherence controller also keeps a copy of the memory link objects of the cache,
meaning that the coherence controller can implement its own methods for sending messages. Receiving messages,
however, must always go through the cache object, as the receiving handler is bound to the cache's method.

#### Creating Links

The links between the current cache object being initialized and other components of the hierarchy are configured
during construction by calling `configureLinks()`. This function is also the biggest function in file 
`cacheFactory.cc`, as the cache object supports several different flavors of configuration for being connected 
to other components in the hierarchy.
In this section, we only cover the simplest configuration, namely, connecting the cache objects to an upper
(closer to CPU) and a lower (further away from CPU) component via point-to-point link, without any packet 
routing. In this configuration, the cache object only has two ports: The high network port, or `high_network_0`, which
connects to a higher level component, and `low_network_0`, which connects to a lower level component.
More complicated topologies, such as those with an on-chip network, can be realized by connecting the cache with other components via more advanced memory link objects. 

At a high level, function `configureLinks()` guesses the cache's link configuration by detecting the ports that are
connected in the configuration, and then sets up the memory link objects based on the guess. 
According to the comment and function body, six port combinations are considered valid (the comment block above
the function header specifies five valid combinations, while in the function body, it also seems that loading
user-defined memory link objects as subcomponents into slot `cpulink` and `memlink` explicitly in the configuration 
file is also supported), and we discuss the simplest among 
them: `high_network_0` and `low_network_0`, which is the configuration where the cache object connects to 
a higher- and lower-level component, respectively, via point-to-point `class MemLink` objects. 

First, `configureLinks()` checks whether either the cache component's slot `cpulink` or `memlink` (or both) is loaded 
with a subcomponent derived from `class MemLinkBase`. If true, then they will be used as the link.
Otherwise, the function checks the connectivity of the following four ports: `high_network_0`, `cache`, 
`directory`, and `low_network_0`. The combination of connection ports is also checked for validity.

If both `high_network_0` and `low_network_0` are connected, the function just initializes two `class MemLink` objects
into subcomponent slot `cpulink` and `memlink`, by calling `loadAnonymousSubComponent()`. Note that in this case,
neither subcomponent needs to be explicitly specified in the configuration file. 
The parameter given to `class MemLink`'s constructor is `memlink` and `cpulink` (unwise naming, of course)
defined right above the `if` code block.
The parameter specifies key `port` as `high_network_0` and `low_network_0`, respectively, such that the 
`class Link` object wrapped within the memory link can be configured correctly.

Recall that, in SST, the topology of components is inferred from the Python configuration file first, 
and then `class Link` objects are initialized based on the topology, and inserted into per-component link maps, 
after which components are initialized. So at component 
construction time, the link objects have already been created, which can be retrieved using the 
port name specified in the Python configuration file.

Region information (which is likely not important) for the two memory links are also given by the parameter objects,
which we do not discuss. 
The last step of link construction is to bind the memory links (and the wrapped link objects) with a handler function
for receiving memory events. 
The handler function is `class Cache`'s member function, `handleEvent()`, which will be called if any of the 
two links receive a message.

Other combinations can also be initialized in the same function as the one we have discussed above. For simplicity,
we skip the rest of the function, because they more or less follow the same logic.

### Cache Initialization

Cache initialization is performed in `init()`. This function handles the case where `linkUp_` and `linkDown_` are 
identical, and the case where they are distinct objects, differently.
In this section, we only discuss the latter, as it is the more general case. The former, however, is almost
identical to the latter, except that only one link is used for sending and receiving instead of both.

On each iteration, the link objects' `init()` is called, with the iteration number passed as the argument.
As we have discussed earlier, the link objects will learn their immediate neighbors, as well as the overall
topology of the memory hierarchy.
If the iteration number of zero, the cache also sends, on both directions, the initialization message on behalf 
of the coherence controller, by calling `getInitCoherenceEvent()` on the controller to obtain the message,
and then calling `sendInitData()` on the memory link objects.

On all iterations, the initialization routine will keep receiving messages on the link objects by calling 
`recvInitData()` repeatedly (i.e., polling) until there is no more message in the current iteration.
We use event processing on `linkUp_` as an example.
For each initialization event object received, the function first inspects its command, and if the command
is `NULLCMD`, meaning that it is an initialization event object that carries a separate initialization
command, then the latter will be obtained by calling `getInitCmd()`. 
For `Coherence` type messages, they will be processed at the current cache, by calling `processInitCoherenceEvent()`
on the coherence controller, and not forwarded, since the current cache also sends coherence message to its neighbors.
In other words, coherence type messages will only travel by one hop.
For `Endpoint` type messages, however, it will be duplicated, and sent to the other direction (`linkDown_`), by
calling `sendInitData()`. 

Messages with non-`NULLCMD` command type will be forwarded to the other direction after being duplicated, 
with the destination being set properly according to the address carried in the message.
In all cases, the originally received message is destroyed, meaning that initialization message's lifetime,
similar to those of the regular messages, is also only one hop.

The event processing on `linkDown_` is similar, but messages of non-`NULLCMD` commands will not be forwarded up,
because otherwise, it would cause an infinite loop as the up links also forward them back. `Endpoint`
type messages will be forwarded still, but the destination is not set to the next hop neighbor, but
remains the same as in the original one.

### Cache Operations

The cache class definition and method implementations are in file `cacheController.h/cc`. 
The call back function for receiving incoming events from both links is `handleEvent()`, the logic of which simply
adds the event object into the new event buffer, `eventBuffer_`, after calling `recordIncomingRequest()` on the 
coherence controller. The latter is solely for statistical purposes, and does not involve any operational details.
Cache operations are implemented in method `clockTick()`, which is registered as the clock tick function
during construction.

At the beginning of `clockTick()`, the cache drains the coherence controller on the outgoing queues for 
both directions, by calling `sendOutgoingEvents()` on the coherence controller. 
Recall that the coherence controller also keeps a copy of the memory link objects of the cache, and hence they could
send their own messages without going through the cache.
Also, this method will not always fully drain the queues, if the outgoing bandwidth per cycle exceeds the 
maximum bandwidth of the coherence controller (we will discuss later in sections talking about coherence controllers).

Then the function clears the state from the previous cycle for access arbitration. Access arbitration can be 
modeled at per-address or per-bank level, which uses data member `addrsThisCycle_` and `bankStatus_`, respectively.

Next, the cache handles retried events. An event is retried if it is rejected by the coherence controller or fails the
access arbitration, in which case the event is added into the retry buffer, `retryBuffer_`. 
The cache processes entries in the buffer one by one, until the buffer is empty, or `maxRequestsPerCycle_` events
have been processed. The latter condition essentially implements a processing bandwidth limit. 
On the other hand, `maxRequestsPerCycle_` can be configured to be -1, in which case there is not bandwidth limit.

Each entry in the retry buffer is processed by calling `processEvent()`. If the entry is accepted, the function
returns `true`, and it is removed from the retry buffer. Otherwise, it just stays there, and will be revisited
in the next tick.

After processing the retry buffer, the cache then proceeds to handle the event buffer, `eventBuffer_`, which stores
newly received events from both links that have not been rejected.
The processing logic is identical to the one of the retry buffer, except that the second argument to 
`processEvent()` is `false`.
The prefetch buffer, `prefetchBuffer_`, is also processed after the event buffer. We do not cover prefetching here,
and we will also skip it in the rest of the section.

Note that the second argument to `processEvent()` indicates whether the event is from the MSHR, or from the
event buffer. The different between these two is that requests that are either 
internally generated (e.g., evictions and write backs), or cause cache misses will be allocated one or more
slots in the Miss Status Handling Register (MSHR) file. These requests will be handled with the flag being `true`,
indicating that the MSHR slot needs to be recycled, if the request is successfully processed.
On the other hand, if an event can be fulfilled immediately, or the MSHR allocation itself is rejected 
(due to the MSHR being full), it will not be inserted into the MSHR, and the flag will be set to `false`.
Detailed discussions on MSHRs are postponed to later section.

An event in the `eventBuffer_` can be in one of the three states after being handled by `processEvent()`.
First, if the event is successfully processed, and no more action is needed in the future, `processEvent()`
will return `true`, and the event is removed from the buffer before being deallocated. 
This is most likely a cache hit, which does not generate internal events, nor require miss handling.
Second, the event can be successfully processed, but it causes internal events being generated, or incurs 
a cache miss. The event needs to be allocated an entry in the MSHR, possibly together with all the 
internal events it generates. In this case, `processEvent()` still returns `true`, meaning that the 
event can be removed from the buffer (because the handling of the event itself is successful), but the 
coherence controller will later on put the generated events into the retry buffer, such that these 
internal events are also handled. In addition, the event object will not be deallocated until the 
response message for the cache miss it has incurred is received. 
Lastly, the event can also be rejected by the bank arbitrator (see below) or the coherence controller. 
In this case, `processEvent()` returns `false`,
and the event object will remain in the `eventBuffer_`. These events will be repeatedly attempted
in the following cycles, until the handlings are eventually successful. 
The second argument to `processEvent()` is set to `false`, since these events are not in the MSHR.

After processing buffers, the cache appends the retry buffer of the coherence controller (obtained 
by calling `getRetryBuffer()` on the controller object) to the cache's 
retry buffer. These events are those that are accepted by the coherence controller, but cannot be 
immediately handled, for which MSHR entries are allocated.
consequently, all events in the retry buffer are handled by `processEvent()` with the second argument 
set to `true`.

### Event Processing

Method `processEvent()` implements event processing function for each individual event.
At the beginning, it checks whether the event represents a non-cachable operation. If true, it is handled separately,
and the operation always succeeds.
Next, for cachable operations, which is the normal case, the cache arbitrates the access by calling `arbitrateAccess()`.
The function decides whether the request can be processed in the current cycle or not using the history of 
previous accesses in the same cycle. 
There are two ways that accesses can be arbitrated. If the boolean flag `banked_` is false, meaning that banked 
cache access is not modeled, then access is arbitrated with data member `addrsThisCycle_`, which tracks the set
of addresses that have been accessed in the current cycle. If the address of the current event has already been
accessed in the same cycle, then the request is rejected.

On the other hand, if banking is modeled, then `bankStatus_` is used for tracking the access status of each bank.
If a bank is accessed previously in the same cycle, the corresponding bit flag is set to `true`, which will cause
a later event on the same bank to be rejected. The bank index of a given address is computed by calling 
`getBank()` on the coherence controller, which forwards the call to the function with the same name in 
`class CacheArray`. The index computing function simply returns the address modular the number of banks,
meaning that addresses are mapped to different banks in an interleaved manner.
(Note: I think this is incorrect, because set-associative caches allow a block to be stored in any of the 
ways of the set the address maps to. The bank index should at least be a function of the set number, e.g.,
be the module of the set number and the number of banks).

After access arbitration, the function just uses a big switch statement to call into the coherence controller
methods based on the event command. Note that both request type and response type commands are processed
in this switch block, since the event handler is registered as the call back for memory links on both directions.
The return value of these methods reflects whether the event is successfully
processed, or requires retry. In the former case, the arbitration information is updated by calling 
`updateAccessStatus()`. In the latter case, the event is kept by the coherence controller in its own retry buffer,
which, as we have seen above, will be moved to the cache's retry buffer at the end of the event handling cycle.

## Cache: Coherence Controllers

The next major part of the cache is the coherence controller. SST's memory hierarchy implements a number of 
different protocols derived from MESI, either to give users more flexibility on choosing the base protocol 
(e.g., MSI or MESI), 
or to adapt to different scenarios (e.g., inclusive or non-inclusive, private or shared, L1 or non-L1).
Each flavor of the coherence protocol is implemented as an individual class, and which class is instanciated 
as the coherence controller of the cache is dependent on both user configuration, and the role of the 
cache in the memory hierarchy.
All coherence controllers are derived from the same base class, `class CoherenceController`, defined in file 
`coherenceController.h/cc` under the `coherencemgr` directory. Each type of the coherence controller
is defined in its own header and cpp files, with the file names being self-descriptive.

### Coherence Controller Construction

`class CoherenceController` is initialized during cache construction, in function `createCoherenceManager()` 
(file `cacheFactory.cc`). The function first reads the access latency of the cache data, specified with parameter
key `access_latency_cycles`, and the latency of cache tag, specified with key `tag_access_latency_cycles`. 
The tag access latency is optional, though, and if not specified, it is by default set to the data access latency.
Then, the protocol is read using the key `coherence_protocol`, the value of which can be `mesi`, `msi`, or `none`.
The boolean flag `L1` is also read with the key `L1`, to indicate whether the cache is an L1 cache or not
(L1 cache requires specific treatments during construction).
The cache type is read with key `cache_type`, which can be of value `inclusive`, `noninclusive`, or 
`noninclusive_with_directory`. 
The function also ensures that L1 caches are always configured to be inclusive, and that non-coherent caches must
be non-inclusive (although the latter case is rare, since most caches need some sort of coherence).
The MSHR object is then created by calling `createMSHR()`. We postpone the discussion on the MSHR to a later section,
and only focus on the coherence controller.

The function then proceeds to preparing the parameters, stored in `coherenceParams`, for initializing the coherence 
controller. We do not cover the meaning of all parameters or switches here, and only introduce them as they are 
encountered during later discussions.
The coherence controller is then loaded into the cache object's subcomponent slot `coherence` as an anonymous
subcomponent. The exact type of the coherence controller to load, however, is dependent on the combination of 
the protocol, the inclusiveness, and the L1 flag.
For coherent, non-L1 caches, if it is inclusive, the controller class that will be loaded is 
`class MESIInclusive`, defined in file `MESI_Inclusive.h/cc`.
If it is not inclusive, and has no directory (i.e., a non-shared cache, likely a private L2), then the class is 
`class MESIPrivNoninclusive`, defined in file `MESI_Private_Noninclusive.h/cc`.
If it is not inclusive, and has a directory (i.e., a shared cache, likely an LLC or shared L2), then the class 
is `class MESISharNoninclusive`, defined in file `MESI_Shared_Noninclusive.h/cc`.
Note that inclusive, non-L1 caches do not get to choose whether a directory is needed or not, and always use 
`class MESIInclusive`, which has inline directory entries.
For coherent L1 caches, inclusiveness does not matter (must be inclusive), and the coherence manager is 
of type `class MESIL1`, in file `MESI_L1.h/cc`.

Non-coherent caches use `class Incoherent` objects (file `Incoherent.h/cc`) and `class IncoherentL1` (file 
`Incoherent_L1.h/cc`), respectively, for non-L1 and L1 caches. Inclusion does not matter for non-coherent
caches, since they are intrinsically non-inclusive. 
Their implementations are just trivial, and we do not cover them in this article.

After loading the coherence controller, the function then reads prefetching-related parameters, before it
sets the up link and down link of the coherence controller with `linkUp_` and `linkDown_` objects of the cache
by calling `setLinks()`.
In other words, the coherence controller also keeps a copy of the memory link objects of the cache, such that
it is also capable of sending memory event objects to other components in the hierarchy.
In addition, the MSHR object of the cache is also passed to the coherence controller by calling `setMSHR()`.

### Construction Performed In Derived Classes

The coherence controller base class constructor leaves the `class CacheArray` object uninitialized, which 
should be completed by the derived class constructors. The main reason is that `class CacheArray` requires 
protocol-specific template argument `T` as the contents of the tag. Such information is not known until 
derived class construction time. 

#### Replacement Manager and Hash Function

The base class, however, provides two method functions that can be called by child class to initialize the 
replacement manager and the hash function, which are both needed by `class CacheArray`. 
Function `createReplacementPolicy()` initializes a replacement manager object as indicated
by the parameter key `replacement_policy`. It supports a few possible values: `lru` for Least Recently Used (LRU),
`lfu` for Least Frequently Used (LFU), and `mru` for Most Recently Used (MRU), `random` for random replacement,
and `nmru` for `Not Most Recently Used`. 
For non-L1 caches, the `-opt` version of the corresponding replacement policy is used, while for L1 caches, the 
non-`opt` version is used.
The replacement manager is eventually loaded, as a subcomponent, into the `replacement` slot of the coherence 
controller.

Function `createHashFunction()` initializes the hash function for the tag array, and loads it as a subcomponent into
the `hash` slot of the controller. Both this function and the previous one are called by derived classes in their 
constructors, when they initialize the tag array (recall that `class CacheArray` takes a replacement manager and a 
hash function object as construction arguments). 

#### The Cache Tag Array

Each derived class of `class CoherenceController` selects its own tag array types. 
`class MESIInclusive` uses `CacheArray<SharedCacheLine>`, which contains sharer and owner information within the 
tag entry, i.e., the cache directory is inline. This is consistent with the fact that `class MESIInclusive`
controller is used for inclusive caches (both shared and private), in which case, all addresses that are cached in
the upper levels must also be present at the current level, and the directory can just be conveniently implemented
in the tag entry. 

`class MESIPrivNoninclusive` uses `CacheArray<PrivateCacheLine>`, which only keeps track of very limited information
about a block, i.e., `owned` and `shared`, indicating whether the block is owned at the current level, or potentially
present at a higher level. For private caches, since there could only be one upper level cache,
using one bit for tracking the block status would be sufficient.

`class MESISharNoninclusive` needs a more complicated mechanism to track block state both at the current level, and
at higher levels. This is because the cache is non-inclusive, and therefore, blocks that are present in the higher
levels may not always be present at the current level. To track blocks in both conditions, the controller
initializes two tag arrays: One directory tag array for tracking blocks in the upper levels and the current cache, 
which is data member `dirArray_`, of type `CacheArray<DirectoryLine>`, and the other is a data tag array for 
tracking blocks only at the current cache (i.e., just the regular tag array), which is in data member `dataArray_`, of type `CacheArray<DataLine>`. Recall that `class DataLine` also keeps a reference to a directory entry, which stores
coherence information of the block.

Lastly, `class MESIL1` uses `CacheArray<L1CacheLine>`, which carries only the most essential information without
coherence states, plus several extra data members for supporting LL/SC and locked/atomic instructions. 
These bits are only present in the L1 tag array, because these high-level operations are only performed in the L1.

Non-coherence caches use `CacheArray<PrivateCacheLine>` and `CacheArray<L1CacheLine>`, respectively, for non-L1
and L1 caches. The reason is straightforward: They do not need to keep coherence information, but L1 cache still
need the extra flags to support certain instructions.

### Coherence Controller Initialization

The coherence controller class does not have an `init()` function, and its initialization is performed by the 
`init()` function of the containing cache controller. 
As discussed earlier, at the first iteration of `init()`, the cache controller will generate a type 
`class MemEventInitCoherence` object, by calling `getInitCoherenceEvent()` on the coherence controller, 
and then this object will be sent to the neighboring caches.
On receiving a coherence type message, the `processInitCoherenceEvent()` will then be called to process it.

`class MemEventInitCoherence` carries the name of the originating cache, stored in base class data member `src`,
the end point type of type `enum class Endpoint` (`type_`, defined in file `util.h`), 
the data block size (`lineSize_`), and a few booleans flags
describing the operational properties of the controller,
such as whether the protocol is inclusive (`inclusive_`), whether write backs will always send write back ACKs
(`sendWBAck_`), whether write back ACKs are expected (`recvWBAck_`), 
and whether the controller tracks the presence of addresses in other caches (`tracksPresence_`).
According to the source code comments, the last boolean flag affects whether clean eviction is needed.

Method `getInitCoherenceEvent()` is implemented in derived classes of the cache controller, and what it does 
is to just create a `class MemEventInitCoherence` object, and initializes it by passing construction arguments
(we do not discuss how each controller class selects their own arguments).
`processInitCoherenceEvent()`, on the contrary, is implemented in the base class, and it takes two arguments.
The first argument, `event`, is the event object received from the link, and the second argument, `source`, 
indicates whether the message is sent by the controller above or below (`true` for above, and `false` for below).
Note that the naming is a little bit confusing. My best guess is that the method was originally designed 
for the scenario where `linkUp_` and `linkDown_` are identical, in which case the argument just indicates 
whether the message is sent by the controller itself from one of the two links and received by the other.

Method `processInitCoherenceEvent()` sets the current controller's data members and booleans flags,
according to the received message. Message sent from the above will cause an update on the local `sendWritebackAck_`
flag, and if the message is from a CPU, then the name of the CPU will also be added into data member `cpus`.
Messages from the below will cause updates on `lastLevel_` (if the below component is not a memory, then
`lastLevel_` will be `false`), `silentEvictClean_` (if the below component uses a bitmap to track
block sharers, then even clean evictions should generate an event to the lower level), `writebackCleanBlocks_` 
(if the lower level is not inclusive, then clean blocks need to be written back explicitly), 
and `recvWritebackAck_` (if lower level will send ACK for write backs, then this one will also expect to
receive it).

### The Coherence Controller Base Class

The base class of the coherence controller, `class CoherenceController`, defines a few handy functions and types 
that are useful for all derived classes regardless of their types. These functions mainly implement low-level
event sorting and dispatching. Derived classes do not override these methods, and just call them as helper functions.

#### Response Objects

`class CoherenceController` has an enclosed data type, `class Response`, which is a wrapper class for `class MemEvent`
objects generated by the coherence protocol. `class Response` contains a pointer to the event object (using base
class type `class MemEventBase`, though, since only link-level information is needed), a timestamp value,
`deliveryTime`, in the component's local cycle that represents the time the response message is generated. 
Recall that a response message can be put into the sending queue before the simulated cycle in which it is 
actually generated, due to the 
fact that tag access delay is not modeled using DES, but just using a miniature queueing model, with a per-tag
timestamp variable remembering the local time when the block becomes free (see Section "Cache Tag Types" for more 
details).
As we have discussed earlier, this violates the principle of DES, since the event object "time travels" to an
earlier cycle, at which time it would not have been in the sending queue. 
To overcome this, `class Response` objects use `deliveryTime` to remember the simulated cycle in which the 
event is generated.
The sending functions should hence ignore response objects with `deliveryTime` less than the current simulated cycle.

The last member of `class Response` objects is `size`, which stores the number of bytes that the memory event object
is supposed to be. This value is not the physical storage it takes on the simulator. Rather, it is the simulated size
of the message, which is used for bandwidth auditing while sending the message.

Also note that `class Response` has nothing to do with `class Request` in the interface object. The object is only
used as a wrapper layer within the controller class. External objects will not find this class useful by any means.

`class CoherenceController` has two internal queues for response objects, namely, `outgoingEventQueueDown_` and 
`outgoingEventQueueUp_`, one for each direction as suggested by the names.
These two queues are of type `std::list<Response>` (note that the source file just imports the entire name space `std`,
which is not a good practice), and they maintain the response objects in a sorted order based on `deliveryTime`.
Objects with the same `deliveryTime` will be ordered based on the order of insertion, meaning that event objects 
generated by the coherence controller will be sent in the same order as they are generated.

#### Queue Maintenance Helper Functions

Method `addToOutgoingQueue()` and `addToOutgoingQueueUp()` insert a response object into 
`outgoingEventQueueDown_` and `outgoingEventQueueUp_`, respectively. The methods iterates over the list
object from the end to the begin using a reverse iterator, until the `deliveryTime` of the response to be 
inserted is greater than or equal to the current response object in the list, or until a memory event
object with the same block address (obtained via `getRoutingAddress()`) is found.
In the former case, either there is no response object at `deliveryTime`, and the one being inserted is the first,
or response objects already exist at `deliveryTime`, and the insertion happens at the 
end of all response objects at `deliveryTime`, i.e., the order of objects with the same delivery time is 
consistent with the order they are inserted.

In the latter case, the response object is essentially delayed by a later response object on the same block address.
This is to guarantee that response messages on the same address are not reordered. 
(Notes: I doubt whether this check is necessary, since the coherence controller handles events in a tick-by-tick
basis. If two response objects on the same address are to be inserted into the queue, then the first one must
have a smaller delivery time, since they must use the same tag entry to derive the delivery time, and these two
response objects will be serialized on that tag entry. This, however, does not hold, if some responses are generated
without being serialized on the tag entry.)

#### Message Helper Functions, Part I

Method `forwardByAddress()` and `forwardByDestination()` implement event message helper functions that assist 
the processing of creating new event objects, and sending the event objects to another component via the memory link.
Method `forwardByAddress()` obtains the base address from the event object to be sent via `getRoutingAddress()`,
and tests on `linkDown_` and `linkUp_` respectively to find the outlet by calling `findTargetDestination()`
on the link object. The function gives priority to `linkDown_` over `linkUp_`, meaning that if the address
falls into the range of both links, then it will be sent down. This is exactly what will happen if 
point-to-point memory links are used, i.e., all event objects sent with `forwardByAddress()` will be
sent downwards (for more complicated topologies, this is not guaranteed).
A heavily used paradigm of this function is to create a new event and copy the address from an
earlier request, or duplicate an earlier request, and then call `forwardByAddress()` on the new event.
This is likely the case where an existing request is forwarded to a lower level, because it could not be
satisfied at the current level, or the current cache generates a request on its own, and sends it down.
The source and destination fields of event objects sent this way still need to be valid, though, as these
two fields might be needed when creating the response event object at the lower level.

Method `forwardByDestination()`, on the other hand, tests on both links by calling `isReachable()` to see if
the destination (a `std::string` object) of the event object is an immediate neighbor. 
A heavily used paradigm of this function is to call `makeResponse()` on the event, which revers the input event's
source and destination, and then send the new event using `forwardByDestination()`. This way, the event
will be sent upwards, most likely as the response message to an earlier request.

#### Message Helper Functions, Part II

There are also message forwarding helper functions that are built based on the two discussed in Part I.
Method `forwardMessage()`, given an existing event, duplicates that event by copy construction.
Optional data payload is set, if it is given.
The delivery time for the event object, which is also the return value, is computed based on the given base 
time argument `baseTime` (although in L1 MESI controller, this value is always zero, meaning that starting
from the current simulated tick) and the current simulated tick `timestamp_`.
If the event object is a cachable, then the access latency being modeled is the tag latency, `tagLatency_`, and
otherwise, it is the MSHR latency `mshrLatency_`.
The newly created object is eventually sent to the lower level by calling `forwardByAddress()`, before the
delivery time is returned.

Method `sendNACK()` just creates a NACK event object based on a given event object by calling `makeNACKResponse()`,
which is essentially just a response event object with the command being `NACK`.
The delivery time is the simulated tick plus tag access latency (i.e., modeling a tag access).
The new event object, with its destination and source being the source and destination of the input object, is 
returned to the sender of the input object by calling `forwardByDestination()`.

Method `resendEvent()` does not create any new event object, but just implements exponential back off for an existing
object, and schedules its sending in a future cycle. This also violates the principle of DES, just like how 
access latency is modeled.
The back off value is computed based on how many reattempts have been made. 
The delivery time of the event is then the current tick, plus tag latency, plus the back off cycles.
The event is sent with `forwardByDestination()`.

Method `sendResponseUp()` is very similar to `forwardMessage()`, but it creates a response event given an existing one,
and sends it up by calling `forwardByDestination()` (since the source and destination is just the inverse
of those in the existing object, which is assumed to be a request received from the above), rather than down.
The delivery time models MSHR latency, if the input event object is from the MSHR (argument `replay` set to `true`),
or models tag latency, if it is a freshly received event object that is just handled for the first time 
(argument `replay` set to `false`).
The delivery time is also returned.
This function also has several overloaded versions, which mainly differ from each other on what the command in the
response object is, or whether dirty bit is passed by argument.

#### Message Helper Functions, Part III

Method `sendOutgoingEvents()` drains the outgoing event queues, until the queues become empty, or until a byte limit
per cycle is reached, whichever comes first.
At the very beginning of the function, the current simulated cycle is incremented by one. Recall that this function
is called at the very beginning of cache object's clock call back, meaning that it is the de facto tick function for
coherence controllers.
The function then drains both queues, `outgoingEventQueueDown_` and `outgoingEventQueueUp_`, with local variable 
`bytesLeft` tracking the number of remaining bytes that can be sent at the current tick. Note that this function
allows partial messages to be sent, i.e., an event object can be sent over a few cycles.
The actual sending is performed by calling `send()` on the corresponding memory link object, and then popping
the front object from the queues.
The function returns a boolean to indicate whether both queues are empty.

#### Function Stubs

The base class also defines stub functions for each type of coherence message it may receive, with the name being 
`handleX` where `X` is the event type. These stub functions, once called, will print an error message and terminate
simulation, in order to indicate that the functionality regarding event type `X` is not implemented.
Derived classes should override at least a subset of these functions and implement the coherence handling logic.

### Miss Status Handling Registers (MSHR)

The Miss Status Handling Register (MSHR) is a critical component of the coherence controller that has serves three 
distinct roles in request handling.
First, requests that cause cache misses cannot be handled locally, and the request must be forwarded to a remote
cache (e.g., a lower level cache for CPU `GET` requests). During this period, the original request will be inserted
into the MSHR, which blocks all future requests on the same address, i.e., requests on the same address are 
serialized by the MSHR.
The request in the MSHR will be removed when the response is received, and later requests on the same address can
proceed.
Second, 
