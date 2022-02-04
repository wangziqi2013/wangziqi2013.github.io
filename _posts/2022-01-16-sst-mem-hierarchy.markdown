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
(e.g., if we are talking about "initializing a data member" within the section of object construction, then it
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
(up to version `11.1.0`, which is the reference version this article assumes), 
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
This is most likely a cache hit, which neither generates internal events, nor requires miss handling.
Second, the event can be successfully processed, but it causes internal events being generated, or incurs 
a cache miss. The event needs to be allocated an entry in the MSHR, possibly together with all the 
internal events it generates. In this case, `processEvent()` still returns `true`, meaning that the 
event can be removed from the buffer (because the handling of the event itself is successful), but the 
coherence controller will later on put the generated events into the retry buffer, such that these 
internal events are also handled. In addition, the event object will not be deallocated until the 
response message for the cache miss it has incurred is received. 
Lastly, the event can also be rejected by the bank arbitrator (see below) or the MSHR. 
In this case, `processEvent()` returns `false`,
and the event object will remain in the `eventBuffer_`. These events will be repeatedly attempted
in the following cycles, until the handlings are eventually successful. 

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

Second, requests that originate from the current cache, such as block evictions and write backs, will use the 
MSHR as an event buffer. These requests are inserted into the MSHR, possibly serialized with existing requests
on the same address, and expect to be serviced just like a normal request.

Lastly, the MSHR is also essential for implementing atomic instructions. It allows a request to temporarily fail
on a locked cache block just because the block is under the protection of an atomic instruction, even if the 
tag array lookup indicates a cache hit. In this case, the failing request will also be inserted into the MSHR,
and retried at a later cycle. 

Since the MSHR buffers requests that cannot be completed at an earlier cycle in which they were processed, 
when a request from an MSHR completes, the next request on the same address will be removed from the MSHR,
and added into the retry buffer, `retryBuffer_`, of the coherence controller.
As have discussed in earlier sections, these requests will be copied to the cache controller's retry buffer
at the cycle end, and will then be reattempted in the next processing cycle.

The MSHR is implemented by `class MSHR`, in file `mshr.h/cc`. Note that the class is neither a component nor a 
subcomponent, since it is always instanciated.

#### MSHR Construction

The MSHR is constructed along with the cache, in the cache object's member function, ``createMSHR``, defined in file 
`cacheFactory.cc`.
The function reads two MSHR parameters: `mshr_num_entries`, which is the number of entries for storing 
external requests (internally generated requests will be counted as an entry, as we will see later),
and `mshrLatency`, which is the latency of accessing the MSHR. The latter will be used, instead of the
cache tag latency, to compute cache block access time, if the request is from the MSHR rather than from the
cache's event buffer.
In addition, `mshrLatency` is an optional argument. If not given, then the default value would be used, which
is one cycle for the L1 cache, and computed from a lookup table with regard to the cache access latency.
Later in the cache constructor, both the MSHR object and its latency is passed to the coherence controller,
by calling `setMSHR()` and by setting the key `mshr_latency_cycles` in the parameter object, respectively. 

#### MSHR Data Structure

The main class, `class MSHR`, is implemented as a mapping structure that translates from addresses to a list of 
waiting events. The class contains a map object, `mshr_`, of type `MSHRBlock` which is defined as 
`std::map<Addr, MSHRRegister>`, a data member `size_` for tracking the current number of external event 
objects in the MSHR, and `maxSize_` which is the size of the MSHR, and is initialized during construction. 
We ignore other data members as they are either prefetching- or debugging-related.

The data type of `mshr_` is `struct MSHRRegister`, which is a per-address structure that contains a list of 
request objects being buffered, `entries`, a data member `pendingRetries`, which tracks the number of 
requests for the address that are in the coherence controller's retry buffer and might be processed later
in the current or future cycles, and other data members, such as `acksNeeded`, `dataBuffer`,
and `dataDirty`. 
We will cover the usage of these data members in details when we first encounter them in the following discussion.

All MSHR entries are of type `class MSHREntry`, which carries a `type` field of type `enum class MSHREntryType`.
The `type` field can be of one of the following three values: `Event`, `Evict`, and `Writeback`. Among them,
the `Event` type entry is for external events that will occupy MSHR space, while both `Evict` and `Writeback`
type entries are for the internally generated eviction and write back requests, respectively, and they do not
occupy MSHR space to avoid protocol deadlock (i.e., external requests can be blocked by internal requests and
fail to be allocated an MSHR entry, but not vice versa). 

Other data members of `class MSHREntry` also play their respective roles in different parts of the coherence
protocol. One of the most commonly seen data member is `inProgress`, which indicates whether the request is 
already being handled and is just waiting for response, and it is only defined for `Event` type entries. 
The flag is set when a `GET` or flush 
request has been issued to the lower level cache, but the response is not received yet. The coherence controller 
will check this flag when trying to schedule a waiting event in the MSHR, and if the flag is set, indicating that 
the current head MSHR entry for a given address has already been scheduled, the coherence controller will not schedule 
it twice.

Each entry type has a unique constructor, and hence the constructor is overloaded. Event type entries is constructed
with the event object and a boolean flag `stallEvict` that initializes the `needEvict` field. 
Evict type entries are initialized with an address, which is the new address that will replace the old address
(which is the address key used to query `mshr_`) after the eviction.
The new address value is needed for cascaded evictions, i.e., one eviction blocks the other and both are in MSHR,
in which case the second eviction needs to evict the new address stored in the first eviction's entry, 
rather than the old address stored in the second eviction's entry.
Also note that the data member for storing these new pointers, `evictPtrs`, is a `std::list<Addr>`, meaning that
multiple addresses can potentially be the new address for an eviction.
Write back entries are constructed with a boolean flag argument, `downgr`, which initializes data member `downgrade`,
to indicate whether the write back is a downgrade from exclusive to shared state, or it also invalidates the block.

#### MSHR Operations

Method `insertEvent()` inserts an event type entry into the MSHR for a given address. Besides the address
and the event object, is also has three arguments: `pos`, `fwdRequest`, and `stallEvict`.
Argument `pos` indicates the position in the list of entries where the insertion should happen. The most common
values are `-1` and `0`, where `-1` means appending at the end, and `0` means inserting at the beginning.
Most events are appended to the MSHR, but high priority events, such as external invalidations (from the lower
level) will override all existing event objects, and be inserted at the very beginning of the list.
Argument `fwdRequest` indicates whether the event is an explicit invalidation from the lower level.
If this flag is set, then two slots, instead of one, will be reserved, since the invalidation in this case 
will be waiting for another request that can unblock the invalidation, which may further allocate an MSHR entry. 
If no extra slot is reserved, the invalidation and the second request will deadlock.
Argument `stallEvict` is just forwarded to the MSHR entry object constructor, and is not used by the method. 

The method first checks whether the MSHR is full or not (recall that if `fwdRequest` is set, two slots are needed).
If full, no allocation will happen, and the function returns `-1`. Otherwise, `size_` is incremented by one.
Then the function creates a new entry, and possibly the register object for the address, if it does not exist, and 
adds the new entry into the requested position of the list in the register object.

Method `insertEviction()` and `insertWriteback()` work similarly by creating the entry of the respective type and
inserting them into the register's list. The difference is that, first, both functions do not check the size, the
reason of which has been discussed earlier. Second, `insertWriteback()` will insert at the beginning of the list,
meaning write back requests have higher priority than every other request waiting in the MSHR.

The above functions are the most frequently used ones in the coherence controller. We will cover other less used 
functions of `class MSHR` when we first encountered them during later discussion.

### Coherence Protocol: MESI L1

We next delve into the realm of the coherence protocol of MESI L1 type cache. As have discussed earlier, this type
of caches are always inclusive, uses `class L1CacheLine` type cache tags, and do not have a directory of any kind.
This type of cache also features a simpler coherence protocol compared with the more general type of inclusive
and non-inclusive caches, since there is no maintenance of coherence for upper levels.
The MESI L1 coherence protocol is implemented by class `MESIL1`, in file `MESI_L1.h/cc`.

#### The General Coherence Handling Flow

Before discussing different classes of coherence operations in details, we first summarize the general rule of
coherence handling as follows:

1. CPU-initiated requests are handled in a first-in-first-out manner, and requests on the same address are 
queued in the same MSHR register (recall that MSHR registers are maintained on a per-address basis) to avoid
race conditions. In other words, the MSHR essentially serves as a serialization point for these requests. 
When CPU-initiated requests observe transient states, and/or outstanding requests in the MSHR register, 
the handler will allocate an MSHR entry, and wait for the preceding requests to be handled, before the
request itself can be handled.

2. A data request can be completed in one of the three manners:
(1) The data request can be immediately completed in the current cycle. The request may or may not have been
waiting in the MSHR in this case. The request will call `cleanUpAfterRequest()` to attempt to 
schedule the next request in the MSHR for retry. This case usually happens if there is a cache hit.

(2) The data request cannot be immediately completed in the current cycle, due to conditions such as cache misses
or downgrades, invalidations, etc., and the request is inserted into the MSHR, if not already. 
In the meantime, the request will initiate internal requests to eliminate the condition that blocks it from being
completed. When the responses to the internal requests are received, the request completes automatically, and the
response handler calls `cleanUpAfterResponse()` to attempt to schedule the next request in the MSHR for retry.

(3) Same as (2), except that after the responses have been handled, the same request is retried by 
calling `retry()`. Then it will either be case (1), or case (2). This case is common if 
the response handler is unsure of the type of the request it is dealing with, and would just like to delegate
state transition and post-response processing to the request handler.
Note that this is merely a programming artifact to simplify coding, and it does not reflect the way that
real hardware handles coherence requests.

3. In particular, data requests that miss the current level will be inserted into the MSHR, and then 
handled in a non-atomic, split-transaction manner when its reaches the front. 
In the first half (request path), if eviction is needed, the controller will insert an eviction entry
in the old address's MSHR register. When that eviction request reaches the front of the MSHR register, and is 
successfully handled, the original data request is retried by calling `retry()`.
If the miss persists on the retry, or, if eviction is not needed, the data request handler will 
forward the data request to the lower level.
The coherence state of the block will also transit to a transient state to indicate a pending transaction.
In the second half (response path), the response is received, which is processed by the response handler. 
The response handler transits the state back to a stable state, and the request is completed 
in the response handler by calling `cleanUpAfterResponse()`.

4. Certain requests may already be in progress, which is checked by calling `getInProgress()`, when their preceding 
requests complete or when a response is received and handled. 
This indicates that the request has completed the first half of the split transaction, and is waiting for 
the responses, and hence need not be retried on completion of the preceding request. 
In this case, these requests will not be retried
by `cleanUpAfterRequest()` and ``cleanUpAfterResponse()``.
Correspondingly, when a request finishes its first half execution, then the handler needs to call 
`setInProgress()` to set the in progress flag.

Note that the reason some requests are already handled while not sitting at the front entry of the MSHR
register is that some requests can "cut the line", and be inserted at the front of the MSHR. When such
requests complete, it is necessary to check whether the next request is already in progress.

5. If a request can be handled immediately, then it will just complete in the same cycle as it is handled,
without involving the MSHR.
Otherwise, the coherence controller will insert it into the MSHR, which will be handled in the future after
all requests that precede it are drained (and as discussed earlier, the waiting request is scheduled for retry
by one of the preceding requests or the corresponding responses).

Insertion into MSHR takes place by calling `allocateMSHR()`, which is defined in the base class controller.
There are three outcomes to MSHR allocation: (1) The allocation succeeds, and the entry allocated is the 
front entry of the register. The function returns `OK`; 
(2) The allocation succeeds, and the entry is not the front entry. The function returns `Stall`;
(3) The allocation fails, due to the MSHR being full. The function returns `Reject`.

6. The caller of `allocateMSHR()` must check the return value, and act accordingly:
In case (1), the request must be handled immediately, which executes the first half of the split transaction. 
The event will be removed from the cache controller's buffer when the handler returns `true`. 
When the second half of the split completes on receiving the response event, the response event handler 
will eventually remove the request from the MSHR.

In case (2), the request must not be handled immediately, since it is not at the front entry of the MSHR.
The caller should just return `true` to the cache controller, which indicates that the request can be removed
from the cache controller's buffer. The request will be scheduled for retry (in fact, its first time attempt)
when the preceding request completes.

In case (3), for L1 caches, the request must not be handled immediately, since it fails to acquire an MSHR entry.
The caller should return `false` to to the cache controller, which indicates that the request must remain
in the cache controller's buffer, and be retried by the cache controller in the next cycle.
For non-L1 caches, if case (3) happens, the caller still returns `true`, and will send `NACK` to the upper
level cache, indicating that the upper level cache is responsible for a retry in the future.

7. External downgrades and invalidations can be received, and they will race with CPU-initiated requests. 
The coherence protocol always orders external events before concurrent CPU-initiated requests, only with
a few exceptions, such as when the cache block is locked, or (for non-L1 caches) when the external
event will cause the second half of the split transaction to fail.

8. Each MSHR register has a pending retry counter, which tracks the number of queued requests 
that will be retried in the current cycle.
This counter is incremented when a new request is inserted into the coherence controller's retry buffer,
and decremented when a request handler executes with `inMSHR` flag set. 
Certain operations (most notably, evictions) require this counter to be zero in order to be able to proceed.

In the following text, we discuss the three major classes of operations, namely, CPU-initiated data requests, 
CPU-initiated flush requests, and external requests (i.e., downgrades and invalidations), in separate sections.
Helper functions are covered when they are encountered for the first time.

#### CPU-Initiated Data Requests

##### High-Level Overview

CPU may initiate three types of data requests: `GETS`, which obtains a block in shared state for read, `GETX`, 
which obtains a block in exclusive state for write, and `GETSX`, which is equivalent to a `GETX`, except that
the block is locked in the L1 cache, until a future `GETX` with an atomic flag hits it.
`GETSX` is essential for implementing atomic read-modify-write instructions.

From a high-level perspective, these requests are handled as either a single transaction, in the case of 
cache hits, or as a few separate atomic transactions, if the access misses. 
The coherence controller first performs a lookup on the tag array. If the tag entry of the requested address
exists, and it is in a state that does not need further coherence actions 
(e.g., `E/M` state on `GETX`), then the access is a hit, and the response is sent back in the same cycle the
request is processed. 

Otherwise, the access incurs a cache miss, and the coherence controller inserts the request into the MSHR (if this
fails, then the request is rejected by the coherence controller, and the cache controller just keeps it, as 
discussed earlier). Meanwhile, a new request is created based on the current request, and the new request is sent
to the lower level to acquire the block.
The rest of the actions depends on whether the address tag already exists in the current cache or not. If it does,
meaning that the coherence action is taken to upgrade the permission of the block (which only happens for `GETX`
and `GETSX`), then no further action is taken.

If, however, the address tag does not exist, then two more transactions are started: eviction and write back.
The coherence controller first attempts to evict the block on the same cycle. If this is not achievable due to the
block being locked, or pending retries on the address to be evicted, the controller creates an eviction request 
using the existing block's address, and inserts it into the MSHR. 
In addition, the controller also creates a request to write back the contents of the evicted block, and also
inserts it into the MSHR.
The write back request might be optional for clean blocks, if the lower level cache does not explicitly request
clean write backs (this is negotiated during initialization, as discussed in cache controller's `init()` function).

The coherence state of the cache block also transits to an transient (unstable, intermediate) state to indicate the 
ongoing transaction of 
block fetching or upgrading. `I` state blocks will transit to `IS` or `IM`, depending on the type of the request.
`S` state blocks will transit to `SM`, if an upgrade is required.
`E` and `M` state blocks will never miss, and the request is handled trivially in one cycle (although `E` state
blocks will become `M` on `GETX` requests).

The second half of the transaction begins when the response event for an earlier cache miss is received.
The coherence controller matches the response event with the outstanding MSHR entry, removes the entry,
and then transits the block state to a stable state.
Extra actions may also be taken, such as locking the cache block, if the request is `GETSX`, or marking the LL/SC's
atomic flag. The transaction concludes by creating and sending the a response message up that indicates the 
completion of the access.

##### handleGetS(), Hit Path

We use function `handleGetS()` to walk over the above sequence as an example. This function is called in the 
cache controller's tick handler to process an memory event object of type `GETS`. 
The `inMSHR` argument is set to `false`, if the event object is from the cache controller's event buffer,
or `true`, if the object is from its retry buffer (which itself is just copied from the coherence controller's
retry buffer at the end of every tick).

At the beginning of `handleGetS()`, a tag lookup is performed on the tag array by calling `lookup()` on `cacheArray_`,
which either returns a valid pointer to the line, if there is an address match, or returns `NULL`.
Note that this lookup operation will update replacement, as the second argument is `true`.
The line state is stored in local variable `state`, and then a switch statement decides the next action.
If the line is in state `S`, `E`, or `M`, indicating a cache miss, then the request is fulfilled at
the current cycle, and the response message is sent by calling `sendResponseUp()`, followed by `cleanUpAfterRequest()`.
Note that the line's timestamp is also updated by calling `setTimestamp()` with the return value of 
`sendResponseUp()`.

The function also calls `removePendingRetry()` to decrement the MSHR register's `pendingRetries` field,
if it is from the cache controller's retry buffer, as an 
indication that one less requests need to be processed for the address in the current cycle.

Method `sendResponseUp()` just takes the request event, creates a new response event by calling `makeResponse()`
(which also sets the source and destination of the response event by inverting the two in the request event),
and simulates the access latency using the input argument `time`, which is the last cycle the cache block is 
busy, and the current timestamp `timestamp_`. 
We have already covered access latency simulation in earlier sections, and do not repeat it here.
The access latency value being used depends on whether the request is from the MSHR (i.e., cache controller's
retry buffer), in which case is data member `mshrLatency_`, or it is from the cache controller's event buffer,
in which case is data member `tagLatency_`.
The response event is eventually inserted into the send queue by calling `forwardByDestination()`, which is 
defined in the base class.

Method `cleanUpAfterRequest()` is called after a request event has been completed. This function is called under the
invariance that the request must be the first in the MSHR's entry list of the requested address.
The function first removes the front (i.e., current) entry from the MSHR register of the given address by 
calling `removeFront()`, if the request is from the MSHR (indicated by argument `inMSHR`).
The function then moves the next request on the same address that was blocked by the completed request into the 
retry buffer, which will then be copied to the cache controller's own retry buffer and processed in the next cycle.
To achieve this, the function first inspects the type of the entry in the MSHR.
If the entry is of event type, and the event object is not already in progress (by checking `getInProgress()`), 
then the event object is scheduled to be processed in the next cycle by inserting it into `retryBuffer_`.
The `addPendingRetry()` is also called to increment the `pendingRetries` counter in the MSHR register, indicating
that some CPU-generated event will be processed for the address in the next cycle.

Note that in the current version of SST (version `11.1.0`), there is likely a bug in `cleanUpAfterRequest()`, where 
curly braces are missing for the if statement `if (!mshr_->getInProgress(addr))`. This way,
the statement, `mshr_->addPendingRetry(addr);`, which is supposed to be only executed when the `if` holds,
will be always executed regardless of the `if` condition. 

If the next MSHR entry is of evict type, the function will then generate one eviction request for every "new address"
stored in the entry (the list of new address is obtained by calling `getEvictPointers()`). 
Note that internally generated eviction requests carry a command of `NULLCMD`, and that they also carry the old
address (i.e., the address to be evicted), `addr`.

Also Note that write back entries in the MSHR register are not retried in `cleanUpAfterRequest()`, even if they 
are at the front of the queue.
The reason is that the coherence controller always sends the write back request to the lower level in the same 
cycle as the entry is added to the MSHR, and hence these entries are just waiting for 
write back responses (i.e., they are always in progress), while blocking all future requests.
The write back entries will be removed when write back responses are received, in which scenario 
`cleanUpAfterResponse()` will be called to retry the next request in the MSHR register.

##### handleGetS(), Miss Path (Despite Eviction)

If the state of the tag is `I`, meaning that the tag address is not found, then a cache miss has occurred, and the
request must be completed with a few more transactions. 
The controller will first attempt to evict a block from the cache, by calling `processCacheMiss()`.
This function may perform the following three operations (some are optional): (1) Adding the request into MSHR,
if not already; (2) Evict the tag if necessary, or schedule an eviction request in the MSHR; (3) Send a write
back request to the lower level for the eviction.
The function may return `MemEventStatus::OK`, `MemEventStatus::Stall`, or `MemEventStatus::Reject`,
which are enum class types defined in file `memTypes.h`. 
In the first case, everything succeeds, and the CPU-generated request can be processed.
In the middle case, the request cannot be handled immediately, but we know that it has already been added to the 
MSHR, so the request can be removed from the cache controller's buffer, and it will be retried later.
In the last case, the request does not even get into the MSHR, and it must be retained in the 
cache controller's buffer.
We postpone discussion of the eviction path to later section, and only focuses on miss handling here.

If the return value of `processCacheMiss()` is `OK`, then the processing proceeds by performing a second 
lookup on the tag array. The second lookup is necessary, since a replacement may have already been made.
Also note that the lookup does not change replacement information, as its purpose is merely just to 
find the tag entry rather than simulating an access.
The controller creates a new request object and sends it to the lower level cache by calling `forwardMessage()`
(which is defined in the base class),
transits the state of the block to `IS`, which is equivalent to `S` but data is missing (so any data related
request on `IS` block should be stalled unless the response arrives).
Finally, the timestamp of the block is updated to the send time, and the MSHR entry of the request is set as 
in progress, such that it will not be scheduled twice.
If the return value of `processCacheMiss()` is not `OK`, the request will not be further processed.
The return value of `handleGetS()` also depends on the return value of `processCacheMiss()`, i.e., 
whether the request has been successfully added to the MSHR. If true, then `handleGetS()` returns `true`,
and the request will be removed from the cache controller's buffer. Otherwise, the method returns `false`,
and the request remains in the buffer, which will be processed in the next cycle.

Note that it is possible that the request is successfully inserted into the MSHR, but the eviction fails,
which will cause `processCacheMiss()` to return `Stall`, and `handleGetS()` will return `true` regardless,
causing the request to be removed from the cache controller's buffer.
At the first sight, this will block overall progress, since the request will never be re-executed. With further 
inspection, however, it is revealed that when this happens, there must already be earlier requests in the MSHR.
When these requests complete, they will insert the current request back into the retry buffer.
This is also the reason why function `handleGetS()` always calls `removePendingRetry()`.

If the request hits an transient state, it will be inserted into the MSHR by calling `allocateMSHR()`, 
if not already, since CPU-generated requests always operate on stable states. 
The older request that is responsible for causing the transient state will put this request in the retry buffer
when it completes. 

##### handleGetS(), Response Path, Part I

When a cache miss occurs, the request object is inserted into the MSHR, and we know that it also must be the
first entry of the MSHR register (because otherwise, the block will be in a transient state, and the request
will not be processed). 
All processing on the address is blocked (excluding invalidations, which is considered as being ordered before
the access operation) until the response event from the lower level cache arrives, in which case, `handleGetSResp()`
will be invoked.

Method `handleGetSResp()` first performs a lookup on the tag array, acquires the cache tag, and sets the block
state to the stable state, `S`. 
We ignore the mundane part of the function on data and memory flags as they are pretty straightforward.
The method then calls `sendResponseUp()` to send a response message to the higher level component 
(for L1 cache, the CPU). Note that the `replay` argument is set to `true` to indicate that the request being
responded to is from the MSHR.
Finally, the method calls `cleanUpAfterResponse()` to remove the front entry from the MSHR, and schedule the following
entry on the same address.

Method `cleanUpAfterResponse()` behaves similarly to its buddy, `cleanUpAfterRequest()`. 
It removes both the front entry of the MSHR register on the response event's address, and the 
request event object that is in the entry as well, if the entry is of `Event` type.
Note that the entry can also be of other type as well, since write backs and flush response handler will 
also call this function, in which case there is no associated request object in the front entry.
The method then adds the next waiting entry in the MSHR register to the retry buffer in a way that is similar to
the one in `cleanUpAfterRequest()`. The only difference is that `cleanUpAfterResponse()` assumes that
the next entry in the MSHR register will never be a write back entry, since write back entries
have higher priority than CPU-generated requests as well as evictions, which are the type of requests that need
to call `cleanUpAfterResponse()` on completion. Additionally, write backs on the same address 
will not stack on each other, since the block state will transit to `I` after the write back entry is inserted 
into MSHR.
This implies that write back entries will never be queued in the MSHR after these request entries.

In the case of `cleanUpAfterRequest()`, the reason that a write back request may be after the front 
request is that external invalidation requests have even higher priority than write backs, i.e., 
when an invalidation is received, if it cannot be handled immediately, the event entry will always be 
inserted as the front entry of the MSHR register. 
After this request is handled, `cleanUpAfterRequest()` will be called to remove its entry from the MSHR, 
in which case the next entry being a write back is truly possible.

##### handleGetS(), Response Path, Part II

It is also possible that `GETS` request receives a `GetXResp` as the response message, which invokes 
`handleGetXResp()` for event handling. This may happen if one or more lower level caches are non-inclusive,
and on the `GETS` request, they just decide to give up the ownership of a dirty block.
The dirty block will be delivered to the requesting cache via `GetXResp`, and the handler will 
see transient state `IS`.

The relevant logic of `handleGetXResp()` is no different from those in `handleGetSResp()`.
In the switch statement, transient state `IS` is handled by transiting to either `M`, if the response data is 
dirty as indicated by the lower level, or to `E` or `S`, depending on whether `E` state is enabled for the
protocol.

##### handleGetS(), Eviction Path, Part I

We have left out the eviction path of `handleGetS()` in the previous sections, which will be covered in this section.
The eviction path starts in function `processCacheMiss()`. 
The function first allocates an MSHR entry for the request, if it is not already in the MSHR. If the allocation
fails, due to the MSHR being full, the function returns `Rejected` without any further action, and the request
will be reattempted in the next cycle.
If the request is already in the MSHR, the function also checks whether the request is, in fact, also the front
event of the MSHR register. The eviction path will only be executed if the request is the in the front. 
This check is necessary, since it is possible that the event was the front entry of the MSHR register, and hence 
was added to the retry buffer in the previous cycle, but an
invalidation is received in the current cycle, which has a higher priority, and will be inserted as the 
front request. In this case, the CPU-generated request should give up the cycle, and let the invalidation be 
handled first by returning `Stall` to the caller. 

If all checks are passed, or the MSHR is allocated successfully, then the value of the local variable `status` 
will be `OK`.
The function then checks whether an eviction is needed by checking whether the argument `line` is `NULL`. 
If true, this implies that the tag lookup does not find the address, and hence an existing block should be 
evicted. Otherwise, the address is already in the cache, and the miss is caused by an upgrade.
In the former case, `allocateLine()` is called to perform eviction and write back, while in the latter case,
no eviction is needed, as the block is already present.

Method `allocateLine()` first calls `handleEviction()` to attempt performing an eviction in the current cycle. 
If the eviction is feasible, `handleEviction()` returns `true`, which means that the block has already been evicted
in the current cycle.
In this case, the tag is updated with the requested address by calling `replace()`, and the line object with the 
new address is returned.
If eviction is infeasible, due to some ongoing actions on the old address, `handleEviction()` returns `false`.
In this case, an eviction entry is inserted into the MSHR by calling `insertEviction()`, and the function 
returns `NULL`. 
Note that the eviction entry is inserted on the old address, with the entry object carrying both the old and the 
new address, while the event entry representing the request is inserted on the new address.

Also note that, in the case where eviction fails, `allocateLine()` returns `NULL`, which causes its caller, 
`processCacheMiss()`, to return `Stall`. This will further cause the request to be removed from the cache
controller's buffer. The request will eventually be retried when the eviction on the old address succeeds. 

Method `handleEviction()` attempts to evict the block given by the replacement manager if feasible.
Note that the second argument is both an input and an output argument.
The function first finds the replacement block, if one is needed (`line` being `NULL`) by calling 
`findReplacementCandidate()` on the tag array with the old address.
It then checks whether the line is locked, and if true, then an atomic instruction is currently half-way, and
eviction must not proceed until the block is unlocked, in which case `false` is returned.
Otherwise, the function checks whether the address also has pending retries by calling 
`getPendingRetries()` on the block address at the beginning of every case block. 
If true, then these retries are logically ordered before the eviction, and eviction could not proceed either,
which causes the control flow to fall though to the `default` case, and `false` is returned.

If the eviction is performed successfully, then the state of the line will transit to `I`. There is no transient
state for evictions, meaning that evictions happen atomically.

Note that there is also likely a coding bug that fails to return `false` directly when the `getPendingRetries()`
check fails. The bug, although not affecting correctness, causes the check with `getPendingRetries()` to be called 
multiple times, until the control flow falls through to `default`. 
A better scheme would be just to add an else to the `if` statement that checks pending retries, and return 
`false` there.

If there is no pending retry on the old address, the block is not locked, and the state of the block is 
a stable state, eviction could then proceed in the current cycle, by sending write back requests to the 
lower level with `PUTS`, `PUTE`, or `PUTM` commands,
for state `S`, `E`, and `M`, respectively. Transient states indicate ongoing transactions on the address, 
in which case eviction should also be delayed (the control flow will hit the `default` case).
The actual request object is sent with `sendWriteback()`, which is just a simple function that creates a 
new event object, computes the delivery time, initializes related fields, sends the request downwards by calling 
`forwardByAddress()`, and finally updates the block's timestamp.
After sending the write back event object, if the cache is expecting acknowledgements for write backs (which is 
configured during `init()`), a write back entry is also inserted into the MSHR for the old address 
by calling `insertWriteback()`. Note that the write back entry is always inserted as the front request of the 
old address.
The state of the block is reset to `I` to reflect the fact that the block has been evicted.

##### handleGetS(), Write Back Response Path

If write back `ACKs` are to be received, the response event of type `AckPut` will be processed by the cache controller 
by calling `handleAckPut()`.
This function is extremely simple: It does nothing except calling `cleanUpAfterResponse()`, which, as we have discussed
earlier, removes the front entry of the MSHR register, which is the write back entry, and inserts the 
event in the following entry into the retry buffer.

##### handleGetS(), Eviction Path, Part II

When `handleEviction()` fails, due to ongoing operations on the old address, an eviction entry is inserted 
into the MSHR register of the old address. The eviction entry will be translated into eviction 
request objects of type `class MemEvent`, with command `NULLCMD`, in method `cleanUpAfterRequest()` and
`cleanUpAfterResponse()`, before being inserted into the retry buffer.

On seeing a `NULLCMD` type event object, the cache controller will call `handleNULLCMD()` to perform the
eviction. The function first obtains the line object with the old address by performing a tag lookup.
The function then reuses `handleEviction()` to perform eviction in the current cycle.
If eviction succeeds, then it calls `deallocate()` on the line object to clear the line's state and mark it
as unused.
Since the eviction has been performed, the originating CPU-generated request on the new address, which is 
obtained by calling `getBaseAddr()` on the event object, is then added to the retry buffer, and the 
new address's pending retries counter is also incremented by one.

Recall that if the eviction MSHR entry has multiple new addresses, then multiple eviction request object will
be generated. Each successful `handleEviction()` in these requests will remove the new address value from the 
eviction MSHR entry (which remains the front entry as these evictions are processed)
by calling `removeEvictPointer()`. 
The last eviction request that is successfully completed will call `retry()` on the old address to schedule
the next entry in the old address's MSHR register, if any.

If `handleEviction()` fails with the eviction entry being the front entry of the MSHR register, then either
the block is still being locked, or the address to be evicted has no longer been in the cache. The latter
is a possible scenario if multiple eviction requests on the same old address are being processed,
in which case the earlier `lookup()` will return `NULL`, causing the `handleEviction()` to pick a new replacement
block with a different address.
The function only handles the latter, though, by comparing the line's address with the old address.
If they mismatch, then the address of the current `line` is used as the old address to insert another eviction
entry into the MSHR.
The `removeEvictPointer()` and `retry()` calls at the end of the branch just serve identical purposes as those 
in the other branch.

As for the former case, in which the old address to be evicted is still locked, the handler just let the
evictions requests be destroyed quietly at the end of the function without causing any effect.
The eviction entry, though, still remains as the front entry of the MSHR with all new addresses in the entry object. 
When the second request of the locked instruction is handled by `handleGetX()`, since the address is guaranteed
to be locked in the cache, the instruction would never retry, never miss the cache, and hence will always succeed on 
the first attempt, never requiring an MSHR. 
After the `GETX` completes (which will hit an `M` state line), the method `cleanUpAfterRequest()` is called,
which, in this case, will see the eviction entry, and the eviction requests will be retried again.

##### handleGetX()

The logic of `handleGetX()` is very similar to those of `handleGetS()`, with a few exceptions:

1. `handleGetX()` will not forward the request to the lower level, if the current level is known to be the 
last level cache, as the last level cache is assumed to be shared by all caches, and hence exclusive permission
can be granted locally. The last level cache is tracked by the flag `lastLevel_`, which is set during `init()`,
if the down link connects to a memory end point.

2. The access will incur cache misses on both `I` and `S` state blocks, causing the block to transit to transient 
state, `IM` and `SM`, respectively. 
`E` and `M` states will be cache hits, and in the case of `E` state blocks, it will transit to `M` state.

3. In the case of cache misses, the request sent down the hierarchy is of type `GETX`. Correspondingly, the response
message received is `GetXResp`, which is handled by method `handleGetXResp()`.
On receiving the response message, `IM` and `SM` state blocks will transit back to the stable state, `M`.
In addition, if the `GETX` request is the second half of an atomic read-modify-write instruction, receiving the 
response will cause the lock counter to be decremented (by calling `decLock()`), indicating the completion 
of the locked instruction.
Note: I am quite sure whether the last part about locked instructions is necessary or not, 
because locked cache blocks will be acquired in `M` state from the beginning, and will never be evicted 
or downgraded until the second `GETX` releases the lock.
This way, it is impossible for a locked `GETX` instruction to cause a cache miss, and hence `handleGetXResp()`
should never see a locked `GETX` as the request type.

4. `GETX` requests with the `F_LOCKED` flag set is regarded as the second half of read-modify-write atomic
instructions. When such a request is processed (it should always hit on the first attempt), the flag is checked,
and if the flag is set, the lock counter of the block will be incremented by calling `incLock()`.

##### handleGetSX()

`handleGetSX()` is almost identical to `handleGetX()`. Its purpose is to acquire a cache block in exclusive state,
and then lock the block in the cache until a later `GETX` on the same address writes to the block. 
This type of requests are used to implement atomic read-modify-write instructions, where the read part corresponds 
to the `GETSX` request, which locks the block in `M` state to avoid data race, and the later write unlocks
the block with a `GETX` request and the `F_LOCKED` flag set.

The only difference between `handleGetSX()` and `handleGetX()` is that, on a cache hit, the lock counter on the
block is incremented by calling `incLock()`. If the access incurs a miss or upgrade, then the `GETSX` request
will be forwarded to the lower level, and the block transits to one of the transient states. 
On receiving the response, which is of type `GetXResp`, function `handleGetXResp()` will check whether the 
originating request is a `GETSX`.
If positive, then the block will be locked as well by calling `incLock()`.

Note that the `GETSX` handler will not check whether the request has the `F_LOCKED` flag set, nor does it
decrement the lock counter on a direct hit. 

#### CPU-Initiated Flush Requests

In addition to data requests, the CPU may also proactively flush addresses out of the cache by issuing flushes.
Two types of flush requests are supported, namely, flush and flush invalidation (flush-inv).
Normal flushes will retain the block in the cache, while downgrading it from exclusive state to shared state, if
the block is valid and not already in shared state. 
Both dirty data and the request itself will be propagated to the lower level, causing a global effect on the 
entire cache hierarchy. 
Flush invalidation, on the contrary, will invalidate the block while carrying dirty data, if any, down the hierarchy.
As a result, this type of the request will totally get rid of an address in the hierarchy, and potentially force 
dirty data to be written into the main memory.
The two types of requests are handled by `handleFlushLine()` and `handleFlushLineInv()`, respectively.

Despite the fact that there is no data to respond, flush requests need to be acknowledged by lower level caches
(unless they are attempted on locked addresses), meaning that they may also require an MSHR entry, and will wait 
for the response message.
Both types of flushes expect the same response message, `FlushLineResp`, which is handled by `handleFlushLineResp()`.

##### handleFlushLine(), Request Path

As with all request handling method, this method first performs a lookup on the tag array, and acquires the 
line object as well as its coherence state. 
Then the method checks whether an MSHR is needed (`inMSHR` is false). If true, then it is further checked whether
the MSHR register for the given address already has entries, which indicates that there are currently 
other transactions being active (including evictions) at the given address, in which case the function just 
attempts to allocate an MSHR for the request, and return.
The check on the MSHR register is performed by calling `exists()` on the MSHR object (if there is no entry in the
register, the MSHR will also remove the register, so address not existing in the MSHR's register map is
sufficient for ensuring that no other transaction is active).
In this case, the method just returns, and the flush is queued in the MSHR waiting for the ongoing transaction
to complete.
Depending on the result of MSHR allocation, the cache controller either removes the request from its internal 
buffer on a success, or retains the request on an allocation failure.

Note that checking for MSHR emptiness, rather than the current coherence state, is a necessary step to perform to 
avoid race condition. Otherwise, the flush may contend with other transactions that does not alter the visible coherence state, most notably, evictions.
Imagine if a flush races with an eviction, then the eviction handling method will mistakenly think that the block
has been evicted by an earlier eviction, and then turn to select a different eviction victim.

If the request is already in the MSHR, then `removePendingRetry()` is called to decrement the register's 
pending retry counter.

The method then checks whether the block is locked. If true, the flush operation fails, and the 
response message is immediately sent to the upper level by calling `sendResponseUp()`, before 
`cleanUpAfterRequest()` is called to remove the event from the MSHR (if it is already in there), and to
add the following entries into the retry buffer.
Note that the flush response event always uses command `FlushLineResp`, and the success status is 
indicated by the event object's `F_SUCCESS` flag, which is not set in this case.

Also note that it is possible for a flush to fail immediately without being added into the MSHR.
This will happen, if (1) the request is not already in the MSHR; (2) there is no contending entries in the MSHR,
and (3) the check for locked block fails. 
This case, however, is handled normally by `cleanUpAfterRequest()`.

If the check passes, then it is certain that the flush will succeed, and an MSHR entry will be allocated, if not 
already yet, regardless of whether there is contention on the same address. 
MSHR allocation failures, as usual, will cause `false` to be returned, and the cache controller will 
retain this request in its buffer for the next cycle.
The address being flushed is also marked as undergoing some transaction by calling `setInProgress()` to avoid it from
being retried multiple times.
Then a flush request is forwarded to the lower level by calling `forwardFlush()`, with boolean argument `downgrade`
to indicate whether the flush also causes the cache to give up ownership (`M` or `E` state lines being downgraded).
This piece of information is essential for the lower level cache to update ownership and sharer information in its 
own directory.

Method `forwardFlush()` is defined in the same class, and it simply copy constructs a new request object, sets the
related fields. Specifically, `dirty` is set if the block state is `M` before the flush, and `downgrade` being
`true` will cause `isEvict_` to be set as well.

After sending the request to lower level, the coherence state of the block will transit to `S_B` state, meaing that
it is effectively an `S` state block, despite that the flush transaction has not completed, and the block is
still waiting for response.

##### handleFlushLine(), Response Path

The response event of flush operation is of type `FlushLineResp`, which is handled by `handleFlushLineResp()`.
On receiving this response, the handler first obtains the line object by a tag lookup.
Then the originating flush request object is also obtained at the front of the MSHR register by calling 
`getFrontEvent()` on the MSHR.
The method completes the state transition: state `S_B` blocks will transit to the stable state `S`, and `I_B`
block will transit to `I`. Note that state `I_B` can either be the result of handling flush line with invalidation,
as we will discuss in the next section, or it can also be because of the `S_B` block was invalidated by an 
external invalidation, which was ordered before the ongoing flush request.
The response event is forwarded to the upper level by calling `sendResponseUp()`, using the success bit 
(via `success()` on the response event) to indicate whether the flush has succeeded or not.
Finally, the method calls `cleanUpAfterResponse()` to conclude response handling.

##### handleFlushLineInv(), Request and Response Path

Method `handleFlushLineInv()` performs a similar task as `handleFlushLine()`, and the logic is almost identical
to the one of `handleFlushLine()`. Differences are:

1. `handleFlushLineInv()` checks whether itself is the front event in the MSHR register by calling `getFrontEvent()`.
If this returns `NULL`, indicating there is a non-event type entry in the front, or the returned pointer is not the
event object, it will stall, and let the front event be handled first. 
It is unclear to me why this function needs this check, while `handleFlushLine()` does not.

2. The block transits to transient state `I_B`, meaning that the block has logically been invalidated, but the
response is still not received.

3. The related path in the response method is the switch case with state `I_B`. On receiving a response, `I_B` blocks
will transit to `I` state.

#### External Downgrades and Invalidations

The L1 cache may also receive external requests from the below cache, i.e., fetches and invalidations.
These requests are generated as part of the coherence protocol for maintaining the one single copy semantics
of writable data, or to facilitate ownership transfer between caches at the same level. 
External events are handled differently from non-external events, mostly in the following aspects:

1. External events are always inserted as the front entry into the MSHR register, and, as a result, is processed
with the highest priority. They do not expect response events from the lower level. 

2. External events may race with other events, and the event handler needs to deal with transient 
states as well as stable states, although it is impossible for some stable states to receive certain 
types of external requests (e.g., coherence downgrade will never been sent to an stable `S` state block).

3. In the case of transient states, external events are always logically ordered before the corresponding event that 
caused the transition into the transient state. 
Consequently, such event is only logically considered as completed when the state moves out of the transient state
after receiving a response.

4. The handlers for external events all share the same common prologue and epilogue. In the prologue, the line object
and the block state is obtained. The CPU is notified of the external events by calling `snoopInvalidation()`,
which just creates an event object of type `Inv` for each CPU registered in the L1 cache during `init()`, and
sends these objects to the CPU.
The epilogue code just does some simple maintenance work, and destroys the event object, as the object is 
always handled in the current cycle.
We do not repeatedly discuss the common prologue and epilogue in the following sections.

5. Source code comments are somehow incorrect in many places, and I suspect that some of the implementations are 
also problematic. I will point this out as we go through the source code.

Five external requests are handled by the L1 cache: `Fetch`, which does not change the current state, and just 
requires a copy of the block to be sent down; `Inv`, which just invalidates the block, if it is not in exclusive 
state (used for invalidating shared copies of non-owners); `ForceInv`,
which invalidates a block regardless of its coherence state (used for invalidating blocks regardless of its state);  
`FetchInv`, which invalidates the block, while also requesting its contents to be sent down
(used for invalidation an owner); and
`FetchInvX`, which downgrades a block from exclusive to non-exclusive, while also requesting its 
contents to be sent down (used for downgrading the owner to be a sharer, and allowing other sharers to 
hold a non-exclusive copy of the block).
These events are handled by method `handleFetch`, `handleInv`, `handleForceInv`, `handleFetchInv`, and 
`handleFetchInvX`,  respectively.

##### handleFetch() and handleInv()

Method `handleFetch()` aims at fetching data from an upper level cache that only has a shared, non-exclusive copy 
of the block. Correspondingly, the switch statement only handles `I` and `S` states and their transient states.
Other states are not handled, and will incur fatal errors.
The function calls `sendResponseDown()` with boolean argument `data` set to `true` for stable and transient `S`
states, indicating that block data is also carried in the response message, which is of type `FetchResp`. 
No response is sent for stable and transient `I` states.
The state of the block remains the same in all cases.

Method `handleInv()` is almost identical to `handleFetch()`, expect that it also transits the block state to `I`,
or the equivalent transient of `I`, and the response type is `InvAck`. 
For example, upgrade transient state `S_M` will become `I_M`, and after the 
response of the upgrade arrives, it becomes `M`. Flush transient state `S_B` will become `I_B`, and when the 
flush response is received, it then becomes `I`.
`handleInv()` is used by the coherence protocol to invalidate shared copies of a block, when another cache 
performs `GETS` or an upgrade.

Note that the source comment for `handleFetch()` says "In these cases, an eviction raced with this request"
under switch case `I_B`. This is incorrect, because evictions do not cause the cache block to transit into
transient states (in `handleEviction()`, a successful eviction will immediately transit the state to `I`).

##### handleForceInv()

Method `handleForceInv()` aims at invalidating a block of given address regardless of its coherence state, and
the response message to the lower level does not carry data.
If the block state is in one of the stable states, or state `S_B`, then the method checks whether the block is locked.
If true, then it cannot be invalidated immediately, and must wait for the atomic instruction to complete.
In this case, an MSHR register entry is allocated for the event by calling `allocateMSHR()`.
If the allocation is rejected, then the handler function returns `false`, which will leave the event in the 
cache controller's buffer for the next cycle, and otherwise, it returns `true`.
Note that the allocation passes `true` to argument `fwdRequest`, and zero to argument `pos`, meaning that two
entries from the MSHR register is reserved (since the invalidation is waiting for another `GETX` request to unlock
the block), and that the invalidation event type entry will be allocated at the front of the register.

After a `GETX` unlocks the block (which will always hit, since the block is locked in the cache in `M` state by an
earlier `GETSX`), the `GETX` handler will call `cleanUpAfterRequest()`, which retries the invalidation.
This time, since the block is unlocked, the invalidation can be processed without trouble.
The block state will transit to `I` for all cases, except `SM`, in which case it will transit to `IM`.
Responses of type `AckInv` are also sent down by calling `sendResponseDown()`, with `data` being `false` for
stable and transient non-`I` states.

Note that this function has a few peculiarities. First, if the block is locked, then it could only be in one
state, namely, state `M`. The source code, however, checks the locked flag in many irrelevant states, which 
may cause MSHR entries be allocated/reserved even if it is not really necessary. 
Second, the method does not call `cleanUpAfterRequest()`, even if the invalidation is from the MSHR. This
will keep the entry in the MSHR forever, and block all other requests on the address.
Third, the method does not send data down even when the state is in stable or transient `M` (i.e., owner state), 
potentially leaving stale data in the lower levels, as the owner holds the most up-to-date data in the hierarchy.
Judging from its behavior, it is also unclear under which circumstances this method will be useful. 

##### handleFetchInv() and handleFetchInvX()

`handleFetchInv()` is almost identical to `handleForceInv()`, except that it always sends response 
with data to the lower level for both shared and exclusive states, and the type is `FetchResp`.
This method also handles all stable and transient states, and can be used to implement recursive invalidation when
a lower level block is evicted (for inclusive caches only) or invalidated.
The method also checks whether the block is locked, and may also allocated one MSHR entry, and reserve for another 
one.

`handleFetchInvX()` is almost identical to `handleFetchInv()`, except that (1) It does not handle `S` and `SM` 
state, since the request is exclusively used to downgrade an owner into a non-exclusive sharer; 
(2) `E` and `M` state blocks will transit to `S` state as the result of being downgraded, and 
send the data response of type `FetchXResp`. stable and transient 
`I` blocks will not send any response, and does not transit to any other state.

Note that in `handleFetchInvX()`, state `S_B` is somehow handled, which is inconsistent with the method's
intended usage. This does not cause correctness issues, though, because it is just that the case statement
will never be seen during the operation.

#### Negative ACKs (NACKs)

The L1 cache may also receive NACK for a CPU-generated request that it has sent to the lower level. 
The NACK indicates that the lower level MSHR is full, and could not accept more events. 
Note that the L1 itself will not send NACK to the CPU, and it will only keep those that are rejected MSHR
allocation in the buffer of the cache controller, which will just be reattempted in the next cycle.

Method `handleNACK()` handles the NACK message. The method extracts the original event that is rejected by the
lower level by calling `getNACKedEvent()` on the NACK event object. 
The original event will be scheduled for sending on a future cycle by calling `resendEvent()`, which is defined
in the base class. The method `resendEvent()` computes the send cycle with exponential back off based on the
number of re-sends, and then inserts the event into the outgoing queue by calling `forwardByDestination()`
with the computed cycle.

### Coherence Protocol: MESI Inclusive

`class MESIInclusive` implements a MESI protocol on non-L1, inclusive caches. This class also inherits from 
the base class, `class CoherenceController`. Compared with L1 MESI coherence controller, non-L1 controllers 
need to implement invalidation and downgrades of upper level blocks, in the case of certain combinations of 
current block states and coherence requests. 
Besides, to maintain inclusiveness, on a block eviction, external invalidation, and downgrade, the upper-level 
blocks on the same address should be recursively invalidated or downgraded.
This suggests that evictions and external requests cannot be easily processed in the same cycle as they are 
received, due to the extra complication brought about by inclusiveness.

The non-L1 controllers, however, also have less per-block state to maintain and less cases to handle when it comes
to locked blocks, and LL/SC transactions. 
Instead, per-block coherence states are maintained for tracking sharers, in the case of a shared block, or 
tracking the owner, in the case of an exclusive block.
Correspondingly, the tag array type used in the class is `CacheArray<SharedCacheLine>`, which only contains 
coherence information, but not operational information as in the L1 cache array.

Compared with non-inclusive caches, this type of the coherence controller can maintain coherence information
for blocks both in the current cache and in upper level caches using the same tag array, since the upper level
blocks are only a subset of blocks in the current cache.

#### Data Members

Data member `cacheArray_` is the tag array of the cache, which maintains both the local state as well as the 
coherence state of the upper level caches on the tag address.
Boolean field `protocol_` specifies whether the clean-exclusive `E` state should be granted to the upper level
cache. The `E` state will be granted, when a `GETS` is processed, and the requestor is the only sharer of the 
block. In other words, the protocol being simulated by the controller is MESI, if the field is `true`, 
and MSI if otherwise.
Data member `protocolState_` is of value `E`, if `protocol_` is `true`, and `S` if otherwise, meaning that
if the protocol is MSI, then shared reads will always only grant `S` state.

Data member `responses` tracks all outstanding invalidation and downgrade requests sent to the upper level caches.
This structure is an `std::map`, with the address being the key, and a pair of `std::string`
and `MemEvent::id_type` being the value. 
The first element of the value is the identity of the receiver, i.e., either an owner, in the case of an exclusively
owned block, or a sharer, in the case of a shared block. The second element is the ID of the 
outstanding request being sent to the receiver.
Entries will be inserted into this structure, when the coherence controller sends invalidations or downgrades,
in one of the three methods: `downgradeOwner()`, `invalidateSharer()`, and `invalidateOwner()`.

#### New Transient States

Due to the existence of downgrades and invalidations, a few new transient states are introduced into the controller.
These states just act as a indicator showing that an ongoing coherence transaction is happening, and that parallel
operations stumbling upon them should either stall, or treat these states as the corresponding stable states.
In other words, these coherence actions are not considered as logically completed, before they transit back to
a stable state.

The coherence controller introduces the following three classes of transient states: 
(1) `S_Inv`, `SB_Inv`, `E_Inv`, and `M_Inv`, which indicate that an invalidation transaction that invalidates
all or some copies of the address in upper level caches is going on;
(2) `E_InvX` and `M_InvX`, which indicate that a downgrade transaction that transfers ownership and perhaps
dirty data from the upper level to the current level is going on.
(3) `SM_Inv`, which indicates that the block is in the process of upgrading from `S` to `M` after issuing `GETX`
to the lower level to obtain ownership, while also in the process of invalidating all shared copies in the 
above level. This state may transit to `M_Inv` or `SM` depending on which transaction completes first.
Note that after the `SM_Inv` state transits back to the stable state `M`, there is still one sharer, which is the
one that issues the `GETX` request and has successfully upgraded its local block.

#### Helper Functions

Before delving into the details of coherence actions, we go over the helper functions that perform invalidation
and downgrades first. These functions are heavily utilized by the rest of the protocol, and hence, it is beneficial
to introduce them first.

##### downgradeOwner(), Request Path

Method `downgradeOwner()`, as the name implies, downgrades the current owner of the block in upper level caches
into the shared state. Since there can be at most a single owner on any address, this method only needs to send
one downgrade request to the owner tracked by the per-block coherence states, and waits for the response.
This method is called in three cases: (1) When a `GETS` request hits a block that has an exclusive owner which is not
the requestor, causing the ownership to transfer from the upper level to the current cache; 
(2) When a flush request hits a block that has an owner that is different from the requestor, causing the ownership
to transfer from both levels to the next level; and
(3) When an external downgrade is received from the lower level, and the current block has an owner in the upper
level, causing the ownership to transfer from both levels to the next level.

In all of the contexts, the event object that incurs the downgrade, which is also the first argument of the method, 
is assumed to have already been added into the MSHR when the function is called.
Method argument `inMSHR` indicates whether the event is in the MSHR when the handler is called. 
If the event is not in the MSHR when the handler is called, then even if one is allocated later during the
function, this argument would be set to `false`, and the latency being simulated is the tag array latency, rather
than MSHR latency.
In addition, since downgrading an address indicates the existence of an owner in the above level, the state
of the block in the current level must also be in one of the exclusive states, because otherwise,
exclusive states would not have been able to be granted to the upper levels.

The function first obtains the address of the downgrade, and creates a new memory event object of command `FetchInvX`.
The new request object inherits the requestor and flags from the originating request object, and the destination
is set to the current owner of the address (obtained by calling `getOwner()` on the line object).
The method also increments the ACK counter in the MSHR register of the address by one, by calling 
`incrementAcksNeeded()`, indicating that only one response from the owner is expected.

The method then updates `responses` by inserting the response to be expected. 
Since only one response from the owner is necessary to complete the downgrade transaction, only one 
entry is inserted into the per-address map, with the key being the owner name, and the value being the
globally unique ID of the downgrade event object.
Eventually, the newly created object is sent to the owner of the address by calling `forwardByDestination()`.
The timestamp of the send operation is also computed, and block timestamp is updated.

##### downgradeOwner(), Response Path

The `FetchInvX` event will be replied by the upper cache with `FetchXResp` event object.
The `FetchXResp` event carries data, and the dirty flag which indicates whether the data is dirty or not.
In the former case, the dirty data should be written into the current cache, which may also potentially change
the local state. 

The response event is handled by method `handleFetchXResp()`. The function never allocates an MSHR, and can always 
complete in the same cycle that it is handled.
The method first obtains the line object and the state. Then it decrements the ACK counter in the MSHR
register by calling `decrementAcksNeeded()`. Note that downgrades always only have one ACK to process 
(i.e., the current one), and hence the ACK counter is not checked and is assumed to be zero.
The method then calls `doEviction()` to simulate the potential state transition caused by writing upper level data 
into the current cache (which will only happen if the dirty flag of the response event object is set).
The `responses` map is also updated to remove the entry that represents the event object we just received.

The method then adds the sender of the message, which is also assumed to be the previous owner, into the sharer list.
Since the downgrade always completes within the same cycle of processing the response event, 
the state of the block also transits back to a stable state. If it is in `M_InvX`, then it will transit back to `M`.
Otherwise, it must be that the block is in `E_InvX` (since only `M` and `E` blocks will transit to these two
transient states at the beginning), and so it will transit back to `E`.
After the downgrade completes, the next event in the MSHR on the address is retried by calling `retry()`. 
Also note that the actual event being retried may or may not be the originating event of the downgrade transaction.

##### doEviction()

Method `doEviction()` is called in `downgradeOwner()` and many other methods to simulate the local write back of
receiving a dirty eviction or invalidation from the upper level.
The function first checks whether the response event carries dirty data by calling `getDirty()`.
If true, it then performs state transition of writing back dirty data with a switch statement.
Since dirty write back can only happen when the upper level has a dirty block, namely, having exclusive ownership,
which further suggests that the current cache must also in an exclusive state (transient or stable),
the method only handles three cases: `E`, `E_Inv`, and `E_InvX`, and they will transit to 
`M`, `M_Inv`, and `M_InvX`, respectively. Other cases are either impossible, or 
do not require transition as they are already dirty (i.e., transient or stable `M` states).

The function then removes the source of the event from the owner field and sharer's lists, if not already,
and caller should update the coherence states further to reflect the change, if any.
At the end, the function clears the `isEvict_` flag in the `class MemEvent` object by calling `setEvict()` 
on the event object. This will prevent the 
event object being processed multiple times from the MSHR.
The new state is also returned to the caller for convenience.

##### invalidateSharer(), Request Path

Method `invalidateSharer()` sends an invalidation message to a specified clean sharer in the upper level.
This method takes, as arguments, the identity of the sharer as a string, and an optional event object
(set to `NULL` if not available). It also takes an argument `cmd` to indicate the command to use for the 
invalidation, which has a default value of `Inv`, meaning that by default, the function just invalidates
without requiring data response (so it only receives `InvAck`).
The method is called directly in handlers `handleForceInv()` and `handleFetchInv()`, when a block of state
`SM_Inv` is to be invalidated. Note that an `SM_Inv` block, despite the fact that the `_Inv` suffix 
implies that invalidations have been issued to sharers, still has one sharer, which is the one who issued 
the `GETX` for an upgrade. The only sharer (not owner, since the upgrade has not completed yet), therefore, 
needs to be invalidated by calling this function.

Besides, the method is also used by helper functions `invalidateExceptRequestor()` and `invalidateAll()` as a 
building block to implement more complicated coherence transactions. 

`invalidateSharer()` first checks that the given sharer is in fact an actual sharer. If negative, this function
does nothing and just returns.
Then it creates a new event object with the given command (default to `Inv`), and then initializes the object either
with metadata from the originating event (if not `NULL`), or just initializes with the name of the current 
cache as the original requestor.
Destination of the event is set to the name of the sharer.

The method then inserts an entry with the name of the sharer and the event ID into `responses`.
The event is sent by calling `forwardByDestination()` after computing the delivery time.
At last, the number of ACKs to expect in the response handler is incremented by 
calling `incrementAcksNeeded()`.

##### invalidateSharer(), Response Path

The response event is of command `AckInv`, which is handled by `handleAckInv()`.
The function first removes the source cache, which is the one whose cache block just gets invalidated,
from the sharer list or from the owner field, depending on whether it is a sharer or an owner.
Then the entry is also removed from `responses`.
Next, the method calls `decrementAcksNeeded()` to decrement ACK counter, and if the counter reaches zero, the method 
just updates the state to reflect the fact that the invalidation transaction has completed.
The transition logic handles all states that have a `_Inv` suffix, and transits them back to the corresponding 
stable states. Non `_Inv`-suffix states are not supported, and will cause an error to be reported.
If the invalidation transaction has completed, the function returns `false`, and otherwise it returns `true`.

The reason that `handleAckInv()` may see a block in transient exclusive state is that both `Inv` and `ForceInv`
expect to be responded by `AckInv` (without data). 
The former will only invalidate shared state blocks in the upper level, 
but this does not prevent the current level state from being an exclusive state, since it is totally normal for
an exclusive state lower level to grant shared states to the upper levels. As for the latter, since
`ForceInv` invalidates blocks of all states forcibly, it needs to handle all possible scenarios including both
exclusive and non-exclusive.

Note that, just like any other response message handler, `handleAckInv()` will call `retry()` after state 
transition to schedule the next entry in the MSHR, if any, for all cases except `SM_Inv`, in which case
`retry()` is called only after checking that the next event is not in progress by calling `getInProgress()`
on the MSHR. 
The reason that `retry()` cannot be blindly called for `SM_Inv` is that this state indicates an ongoing upgrade
transaction, the event entry of which is also in the MSHR, and it must not be retried multiple times. 
The MSHR front event should eventually be retried by function `cleanUpAfterResponse()`, which does not 
check the in progress flag of the MSHR entry, when the `GETX` response event is received from the lower level. 

##### invalidateOwner(), Request Path

Method `invalidateOwner()` is similar to `downgradeOwner()`, except that it sends `FetchInv` command for invalidation
rather than `FetchInvX` for downgrade. Correspondingly, the response event is of command `FetchResp`, rather than
`FetchXResp`. The response is handled by method `handleFetchResp`.

`invalidateOwner()` is directly called in method `handleGetX()`, when the block is in `E` or `M` state, and the
block is exclusively owned by an upper level cache (which cannot be the requestor).
The method is also used by another helper function, `invalidateAll()`, to implement the case where only a single
owner is to be invalidated.

Note that `invalidateOwner()` may just fail to invalidate and return `false`, if the given block does not have 
an owner (the `owner` field is empty string). This property is being relied on in `invalidateAll()` as a quick check
to see whether the block is exclusively owned, or just shared.
Besides, `invalidateOwner()` allows a custom command to be passed as the command of the event being sent to the 
owner of the address. If not given, the command defaults to `FetchInv`.
The only case where the default command is overridden is in `handleForceInv()`, which calls `invalidateAll()`
with the command `ForceInv`, and the command will be passed to `invalidateOwner()` as well.

##### invalidateOwner(), Response Path

As mentioned earlier, the response event is of type `FetchResp`, if the default command is used.
The event is handled by method `handleFetchResp()`.
What the handler does is simple. First, it decrements the ACK counter in the MSHR register, and then
removes the entry representing the earlier invalidation request from `responses`.
It also calls `doEviction()` to simulate dirty write back and the respective state transition, which we have
covered earlier.
Eventually, the method performs state transition on completion of the transaction. 
The state transition only supports two possible states, namely, the transient `M`, or the transient `E`, which will
transit to stable `M` and `E`, respectively.
The method also calls `retry()` to schedule the next entry in the MSHR for retry, if there is any.

##### invalidateExceptRequestor()

Method `invalidateExceptRequestor()`, as the name implies, invalidates all other copies of a block except the 
requestor of a given event. 
This method is used when a `GETX` hits a block in the cache, and it is indicated by the coherence state 
that the address is also being shared in upper level caches in shared states. 

The method's logic is very straightforward: It enumerates the given block's sharer, and for each sharer that
is not the source of the given event (which is a `GETX` issued by one of the upper level caches), then
an invalidation will be sent to the cache by calling `invalidateSharer()`.
For each invocation of `invalidateSharer()`, the timestamp of the block will be updated, and the final timestamp
is in local variable `deliveryTime`, which will be set as the block's timestamp after the operation.
The method returns `true`, if at least one invalidation request has been issued, meaning that the block should 
transit to a transient state until the responses are received (the method itself does not perform any state
transition, though).

Note that the method uses the default `cmd` argument of `invalidateSharer()`, which is `Inv`, indicating that it
intends to invalidate shared blocks in the upper level.

##### invalidateAll()

Method `invalidateAll()` just invalidates all sharers or the owner of an address, regardless of its current status.
This function implements recursive invalidation, which happens when an address from the current cache is removed, 
due to eviction, flush, or external invalidation.
This method is called by handler functions `handleFlushLineInv()`, `handleInv()`, `handleForceInv()`, 
`handleFetchInv()`, and `handleEviction()`.
The method also takes an optional argument, `cmd`, which specifies a command to be used. The command is set to 
`NULLCMD` by default, meaning that the method is free to choose the most appropriate command based on the 
sharer and owner information of the block.
The only occasion where a non-default command is used, though, is in method `handleForceInv()`, in which case
`ForceInv` is passed as `cmd`, forcing an invalidation to be performed regardless of the block state in the 
upper level.
The method returns `true`, if the block to be invalidated in the upper level is owned, or `false` if otherwise.

The method calls attempts to call `invalidateOwner()`, with the command being either `FetchInv`, if not specified
in the argument, or whatever in the argument, if otherwise.
If `invalidateOwner()` returns `true`, meaning that the block is indeed owned by an upper level cache, the 
function returns `true` as well.
Otherwise, if `invalidateOwner()` returns `false`, meaning that the block does not have an owner, and all copies
in the above level are shared (or it is not cached by upper levels at all), then the method enumerates
all sharers, and calls `invalidateSharer()` on each of the sharer.
The command, if not explicitly given, is set to `Inv` by default.
The timestamp of the block is updated in the same way as in `invalidateExceptRequestor()`.

#### Handling Write Backs

There are also functions that handle write backs (event type `PUTx`) induced by eviction from the upper level. 
Recall that when a write back event is received, if the cache is configured to send an acknowledgement, or the upper 
level expects to hear back from the write back request, then 
the write back will be inserted as the front entry of the MSHR in the upper level, 
and the acknowledgement should be sent from the lower level.
Also recall that, when eviction is being requested due to a replacement, `handleEviction()` will check (1)
Whether the block is in one of the stable states; (2) Whether there are no pending retry on the address to be
evicted; and (3) Whether the address is not locked by an atomic instruction.
If all three criteria are satisfied, the eviction is handled by issuing a `PUTS`, `PUTE`, or `PUTM`, respectively,
for block state `S`, `E`, and `M`.

##### Race Condition Between Eviction and Invalidation

When an eviction operation succeeds, the cache block immediately transits to `I` state, without transitioning into
an intermediate state first. This design is intentional, because not every configuration requires an `AckPut` be 
sent by the lower level after receiving the eviction, and for those that do not, transitioning into a transient 
state after eviction would mean that there is no further event that cause the state to transit back. 

This protocol simplification creates a window of vulnerability, in which the lower level cache still
marks the upper level cache as a sharer or owner, while the upper level cache has already evicted the block, with 
the state transited to `I`, due to the fact that it may take several cycles for the eviction message 
(i.e., `PUTx` events) to be delivered or processed. 
As a result, in the window of vulnerability, if invalidations or downgrades are sent to the upper level cache
whose eviction has been completed locally but not yet handled by the receiver, there would be an inconsistency, 
since the receiver in the upper level will not respond to downgrades or invalidations on a non-existing block, 
while the issuer expects a response from the upper level, causing a race condition.

Luckily, the race condition is still solvable, because the sender of the downgrade or invalidation will eventually
receive the put message. In addition, by checking the number of ACKs expected in the MSHR register of the address, 
the sender is also able to identify
whether the put message originates from an unsolicited eviction, or is the result of the race condition. 

##### sendAckPut()

This method is called by all put handlers to send a response to the upper level cache as acknowledgement,
if the data member `sendWritebackAck_` is set (which is initialized in `init()`).
The method's logic is simple: Given the put event object, it creates a new event object by calling `makeResponse()`,
sets the source and message size, and sends the event by calling `forwardByDestination()`. 
The latency of the event is always the tag latency, since put events are always handled in the same cycle
when it is received, and hence no MSHR entry is needed.

##### handlePutS()

Method `handlePutS()` may handle an unsolicited eviction, or treat it as the response event to an earlier 
invalidation due to a race condition. Note that `PUTS` will not race with downgrades, since `S` state blocks
in the upper level will never cause a downgrade to be issued from the current cache.

The method begins with the usual prologue as in other handler functions. Most notably, it calls `removePendingRetry()`
if the `inMSHR` flag is set, but it is impossible for this event to be inserted into the MSHR, and the invocation
will never be executed.
The method then calls `doEviction()` to perform the local state transition of writing evicted data, in which case
will perform both state transition of the local state (no-op in this case, since `PUTS` does not contain dirty data), 
and remove the source of the event from the sharer list or from the owner field (in this case, always sharer list).
If the source also has an entry in the `responses` structure, the corresponding entry will be removed,
just as if an `AckInv` has been received.
In addition, if the ACK counter on the address is not zero, then it will also be decremented.
If the ACK counter reaches zero, the invalidation has been completed, which will cause the flag `done` to be set.
The helper function `sendAckPut()` is also called, if flag `sendWritebackAck_` is set, to send the `AckPut` back
to complete the eviction operation in the upper cache.

The method then performs local state transition.
If the state is stable, or is `S_B`, meaning that the event is an unsolicited eviction, no state transition is needed.
Otherwise, if the states is one of the transient states waiting for invalidation to complete, i.e., those
with the suffix `_Inv`, then they will only transit back to the corresponding state without `_Inv` suffix, if
`done` is set to `true`, and then call `retry()` to schedule the originating event that caused the invalidation.
The only exception is `SM_Inv`, which should also check whether the next event object is already in progress
(the reason of which has been discussed earlier).

Note that the `S_B` state means an ongoing flush operation has already forwarded the flush request to the lower level,
but has not received any response yet. This does not preclude the possibility of having shared state blocks in the
upper level, as flush itself only downgrades dirty blocks on its way.
`SB_Inv`, on the other hand, is observed when an ongoing flush operation races with an external invalidation, which
itself raced with the eviction. 

##### handlePutE()

Method `handlePutE()` is called when a `PUTE` event is received. It is similar to `handlePutS()`, with 
the state transition table being the major difference.
Since a `PUTE` indicates the existence with ownership in an upper cache, which, in return, indicates that the
current level must also have exclusive state, state transition may only happen on one of the few transient and
state states of `E` and `M`.
Specifically, the state transition action only accepts state `E`, `M`, as well as the `_Inv` and `_InvX` versions.
Transient states will become their stable counterparts, and stable states do not change at all.

##### handlePutM()

Method `handlePutE()` is called when a `PUTM` event is received. Its logic is identical to `handlePutE()`, but the
actual operations being performed differ, since `doEviction()` will now also perform some state transition to
simulate the local write back, in addition to removing the owner from the local coherence state.

#### CPU-Generated Data Requests

##### handleGetS(), Request Path

Method `handleGetS()` in the inclusive cache shares an overall similar structure as the one in the L1 cache.
In this section, we skip the parts where the logic is identical to those in the L1 cache, e.g., we do not repeatedly
explain invocations of helper functions, such as `removePendingRetry()`, `setInProgress()`, 
`cleanUpAfterRequest/Response()`, `allocateMSHR()` and the related logic, and so on.
To simplify discussion, we also only focus on the difference between the handlers in the inclusive cache and the L1 
cache.

The handling of state `I` and `S` are almost identical to those in the L1 cache. In the case of 
state `I`, the sharer is added to the list only after the response message of the forwarded `GETS` is processed,
i.e., when the block is in `IS` state, the sharer list does not contain the requestor.
For state `S`, since it is a direct hit without further forwarding, the sharer list is updated immediately
in the same cycle.

The handling of `E` and `M` state (they share the same logic) need to check whether the upper level cache 
has exclusive ownership, by calling `hasOwner()`.
If true, then the owner must be degraded first, by calling `downgradeOwner()`, after 
successfully allocating an MSHR entry. The state transits to `E_InvX` and `M_InvX`, respectively, for state `E` and 
`M`, and the `GETS` request will be retried by the downgrade response handler when the downgrade completes.

If the address does not have any owner, but has sharers, then the new sharer will be added into the list, and 
the response event will be `GetSResp`. If there is no existing sharer, meaning that the requestor will become
the sole holder of the shared copy, then the state granted to the upper level will be `GetXResp`, and the 
upper level block, on receiving this message, will transit into `E` state.

If MSHR allocation fails, an NACK that contains the current event object will be sent back to the upper level 
cache by calling `sendNACK()`. The upper level cache is expected to re-send the event after waiting for 
a while.
The method always returns `true`, such that it will be removed from the cache controller's
buffer regardless of the success status.

Method `processCacheMiss()` and `allocateLine()` are also identical with those in the L1 cache.
Method `handleEviction()`, however, differs from the one in the L1 due to the fact that eviction may also
cause recursive invalidation.
In `handleEviction()`, the method checks whether there are pending retries on the address. If true, then
it just returns `false`, and the caller will insert an eviction entry into the MSHR register.
Otherwise, the method first calls `invalidateAll()` to send `Inv` or `FetchInv` to the upper level.
If `invalidateAll()` returns `true`, meaning that at least one invalidation is sent, then the 
state of the block transits to the corresponding transient state (with `_Inv` suffix). Local variable
`evict` is also set to `false`, to indicate to the caller that an eviction entry should be inserted into the MSHR
register, such that it can be retried from the MSHR when all responses are received.

On the other hand, if `invalidateAll()` returns `false`, meaning that there is nothing to invalidate, then
the eviction can proceed immediately. In this case, a write back request is sent to the lower level
by calling `sendWriteback()`, and the state of the block transits `I`. 
The local flag `wbSent` that tracks whether write backs have been sent is set to `true`.

At the end of the method, a write back entry is inserted into the MSHR, if a write back has been sent (`wbSent`), 
and that the cache is configured to expect write back ACKs. 
The method returns the value of `evicted`, which, if set to `false`, will cause the caller to insert an eviction
MSHR entry.

##### handleGetS(), Response Path

The response event to `GETS` is `GetSResp`, which will be handled by `handleGetSResp()`. 
The handler is largely the same as the one in the L1 cache, with the only exception being that the 
original requestor of `GETS` is added to the block's sharer list.
Besides, the `GETS` response event is also sent to the upper level, by calling `sendResponseUp()`.

##### handleGetX() and handleGetSX(), Request Path

Method `handleGetX()` handles `GETX` request from the upper level, which can be a read or upgrade. 
Blocks of `I` state is handled in the same way as in the L1 cache.
Blocks of `S` state will always incur a cache upgrade transaction, with an optional invalidation.
The method first forwards the `GETS` to the lower level by calling `forwardMessage()` to start the
upgrade transaction. Then it calls `invalidateExceptRequestor()` to invalidate all potential sharers of
the block. Note that since the state of the line itself is non-exclusive, there cannot be exclusive states
in upper level caches, and hence only issuing invalidation is sufficient.
If `invalidateExceptRequestor()` returns `true`, indicating that at least one invalidation has been sent,
the state will transit to `SM_Inv`, to indicate that there are two transactions going on, one is upgrade
transaction from `S` to `M`, while the other is invalidation.
On the other hand, if `invalidateExceptRequestor()` returns `false`, then no invalidation is issued, and the
state transits to `SM`.

`E` state and `M` state are handled in the same manner. First, if the address has non-exclusive sharers, which
is checked by calling `hasOtherSharers()`, then an MSHR is allocated, and `invalidateExceptRequestor()` is
called to invalidate these sharers. 
Otherwise, if it has an owner, checked by `hasOwner()`, then the owner will be invalidated by calling 
`invalidateOwner()`.
In both cases, the method returns, and will wait for the invalidation transaction to complete, before the
current event is retried by the invalidation response handler.
The state of the block also both transits to `M_Inv`. This suggests that the dirty state in the 
non-L1 caches will be marked as early as the `GETX` from the L1 is processed (rather than when the dirty block
is actually written back).

If neither of the above two cases hold, the `GETX` can be processed immediately by adding the requestor as
the exclusive owner of the address.

Again, if any of the MSHR allocation fails, NACK will be sent back to the requestor.

Method `handleGetSX()` is completely identical to `handleGetX()`, since non-L1 caches do not implement
atomic instructions.

##### handleGetX() and handleGetSX(), Response Path

The response event of both `GETX` and `GETS` is `GetXResp`, which is handled by `handleGetXResp()`. 
The main body of the handler is the logic to perform state transition.
If the state of the block is `IS`, meaning that the cache has issued a `GETS`, but the lower level
granted exclusive ownership, then the state will transit to either `M`, if the response event carries
dirty data (which will happen if the lower level cache is non-inclusive), or transit to `E`.
In addition, the current cache also decide whether to grant shared or exclusive ownership to the 
upper level. The decision is made by checking the number of entries in the MSHR register
(`protocol_` and the line state are also checked, but they are not of major interest). If the MSHR
register does not contain any other request other than the original `GETS`, then exclusive ownership
is granted by calling `sendResponseUp()` to send a response event with the command `GetXResp`, and
the original requestor is also added as an owner.
Otherwise, since the MSHR already queues a few requests on the address, it is likely that the following
operations will downgrade or invalidate the current owner. In this case, only shared state is granted,
by calling `sendResponseUp()` with the command being `GetSResp`.

State `IM` and `SM` blocks are processed similarly. The block just transits to `M` state, and the
original requestor is added the owner.
The same response is forwarded to the upper level by calling `sendResponseUp()`.

For state `SM_Inv`, this indicates that the upgrade transaction has completed before invalidation does.
The state transits to `M_Inv`, but no response is sent, and the original event is not retried.
When the invalidation transaction also completes, the original `GETX` event will be retried, and the response
event is sent to the requestor in the handler of the `GETX` event.

#### CPU-Generated Flush Request

Recall that flush requests are generated by the CPU to downgrade or invalidate a block from the entire hierarchy.
Flush requests are first processed by each component on the path, performing the downgrade or invalidation
locally, after which they are forwarded to the lower level.
The forwarded flush request may also carry dirty data, if dirty blocks are downgraded or invalidated along the way.
Cache blocks transit to the transient state `S_B` or `I_B`, after the flush requests are forwarded to the lower 
level, and before a response is received.
Flush response is generated by the lowest level component of the hierarchy (likely main memory), and is forwarded 
up the hierarchy following the same path.

##### Race Condition with Downgrades or Invalidations

In non-L1 caches, flush requests may race with an ongoing downgrade or invalidation, in a way that is similar to
how `PUTx` requests race with them.
In fact, flushes just achieve the same effect as downgrades (`FlushLine`) or invalidations (`FlushLineInv`), except that they
are unsolicited requests since it is the CPU who originally initiates the request.
In addition, the window of vulnerability in `PUTx` handling also exists for flush handling, that is, between the 
time point when the flush is issued to the lower level, and the point when the lower level receives the 
flush request and updates the coherence states, the coherence state recorded in the lower level will be
stale. If a downgrade or invalidation is issued to the upper level in this window of vulnerability, then these 
event may not be handled properly by the upper level, and hence extra steps need to be taken, in the lower level
cache, to properly identify the role that a flush request plays. 

There are two scenarios where the race condition could occur and disrupt normal event processing.
First, if the upper level cache issues a regular flush, downgrading its exclusive block into `S_B`
state block, followed by the lower level cache issuing a downgrade, then the downgrade will never be 
responded to by the upper level cache, since `S_B` state blocks just ignore downgrades.
In this case, the flush request, if it contains data, indicating that it performs ownership transfer, should
be considered as the equivalence of a `FetchInvXResp` with ownership transfer.

In the second scenario, a `FlushLineInv` is issued from the upper level from any state, and the block transits to
`I_B`. Meanwhile, the lower level issues either a downgrade or an invalidation to the upper level. In this 
scenario, since `I_B` blocks do not respond to any external events, the downgrade or invalidation will never
receive the response from the upper level cache.
To resolve the issue, the lower level cache must treat the `FlushLineInv` as a `FetchInvResp`, or as a `FetchInvXResp`,
depending on the pending transactions in the lower level (since an invalidation is also a downgrade).

##### handleFlushLine(), Request Path

Method `handleFlushLine()` handles the flush line event, which may or may not carry dirty data evicted from the 
above level. The method first allocates an MSHR for the event, and simulates the local write back, if any, by 
calling `doEviction()`. Note that local write backs will always be simulated on the first and only the first invocation
of the handler, regardless of the MSHR allocation status, and will not be executed repeatedly on later retries or 
NACKs. The function, under this context, will either do nothing, if the write back does not involve a downgrade,
or perform local state transition and/or remove the requestor from the owner list, if 
the event involves a downgrade (indicated by `isEvict_` flag) and/or the data it carries is dirty (indicated by 
`dirty_` flag). Besides, on later tries of the event, `doEviction()` will effectively be a no-op, since the 
evict flag of the event object is cleared.
If the flush is equivalent to a downgrade, then local variable `ack` will be set to `true`.

Note that, if a downgrade happens, then after `doEviction()`, the upper level cache will be added as a sharer,
and calling `hasOwner()` on the block will return `false`. 

The method then performs state transition and/or coherence actions with a switch block.
For `I` and `S` states, the flush will not incur any local action, and the switch is essentially a no-op.
For `E` and `M` states, if MSHR is allocated successfully, then `downgradeOwner()` is called to issue a downgrade
to the upper level, and the request is stalled in the MSHR until downgrade succeeds by changing the 
status to `Stall`. The state of the block also transits to the corresponding `_InvX` version to indicate that
a downgrade is going on.

The race condition discussed above happens, if blocks are already in `E_InvX` and `M_InvX` states, indicating 
that when the flush line request arrives, there is already a downgrade transaction on the address.
In this case, the `ack` flag is checked. If `ack` is `true`, meaning that the ownership transferred has occurred
with the flush line request, then it should be regarded as a valid response to the downgrade transaction.
The pending response is hence removed from `responses`, and the ACK counter is decremented by calling 
`decrementAcksNeeded`. Besides, the block state changes back to the corresponding stable state, indicating the
completion of the downgrade.
The original request that caused the downgrade is retried by calling `retry()` as its downgrade transaction has 
completed.

The race condition may also occur if the blocks are in `E_Inv` and `M_Inv` state, and if the head 
entry of the MSHR is a `FetchInvX` request. (Note: I have no idea why this race will even happen - it does not
seem obvious to me why there would be an external downgrade at MSHR head, and the state indicates invalidation).
In this case, the expected response is also removed, and the downgrade transaction is retried.
Note that state transition is not performed in these two cases, which are expected to be performed by the
downgrade transaction. 

For all other transient states, no race condition has occurred, and the flush is ordered after all existing 
requests by the MSHR.

After the switch statement, the method checks the local variable `status`. If it is `OK`, indicating that the current
request is in the first entry of the MSHR register, and there is no pending response, then the flush
operation is performed by forwarding the request to the lower level, via the helper method `forwardFlush()`.
Flag `downgrade` is set, if the block state indicates exclusive ownership. 
The state then transits to `S_B`, and the request is marked as being in progress in the MSHR register by
calling `setInProgress()`. Later requests that check the in progress flag will either wait for it to
complete, or will not retry this request.
The flush request is eventually completed and removed from the MSHR, when the flush response is received
from the lower level.

##### handleFlushLine(), Response Path

The response event to flush line event is `FlushLineResp`, and it is handled by `handleFlushLineResp()`.
This method is the same as the one in the L1, which performs state transition from `S_B` to `S`, or from
`I_B` to `I`.
It also propagates the response events up by calling `sendResponseUp()`.
The flush line event is removed from the MSHR, and the next entry is retried, by calling `cleanUpAfterResponse()`.

##### handleFlushLineInv(), Request and Response Path

Request `FlushLineInv` performs an unsolicited eviction of a block, if it exists in the cache, and, as 
discussed earlier, this request may also race with an going downgrade or invalidation.
At the beginning of `handleFlushLineInv()`, the request is inserted into the MSHR.
If the event is an eviction (which is set as long as the upper level cache had contained the address), 
then the ACK counter of the requested address is checked to see if there is any outstanding invalidation or 
downgrade response to be expected.
If true, then the response is removed from `responses`, and the ACK counter is decremented, as the flush inv event 
counts as both downgrade and invalidation.
Note that this is universally handled for all cases, and only for the first attempt of the event even if it 
is NACK'ed due to MSHR allocation failure.
Though, in some cases, there will not be any response to
expect, in which case what is described above will not have any effect except `doEviction()`.

The method then performs state transition and coherence actions with a switch block.
`I` state blocks (i.e., not found) do not need any action nor transition.
For stable state blocks, if MSHR allocation succeeds, then `invalidateAll()` is called to invalidate all copies
of the blocks from the upper level, and if at least one invalidation is issued (by checking the return value), 
then the state transits to the corresponding transient state, and local variable `status` is set to `Stall`,
indicating that the request should not be further propagated until the invalidation transaction completes. 

On the other hand, `_Inv` and `_InvX` state blocks will first check `done` flag, which indicates whether there
are still pending responses to be expected. If `done` is `true`, then these blocks will transit back to the 
corresponding state without `_Inv` or `_InvX`, and `retry()` will be called to retry the event at the 
head of the MSHR register that initiated the downgrade or invalidation transactions.

After the switch block, if local variable `status` is `OK`, indicating that the request is at the head of the MSHR,
and that no responses is being expected for the request itself, then the `FlushLineInv` is propagated to the 
lower level by calling `forwardFlush()`, and the state of the block transits to `I_B`.

The response event of `FlushLineInv` is `FlushLineResp`. The event is handled by method `handleFlushLineResp()`,
which has already been discussed above.

#### External Downgrades and Invalidations

Non-L1 cache handles external downgrades and invalidations differently from the L1 cache, mostly because of the 
need to recursively downgrade or invalidate the upper level copies, and to deal with the contention between the
external requests as well as unsolicited evictions or flushes from the upper level. 

##### handleFetch()

Method `handleFetch()` is almost identical to the one in the L1 cache. It only works on shared, non-exclusive 
copies of the
block, and it sends the contents of the block in a `FetchResp` event, which always contains clean data (i.e.,
eviction flag is set, but dirty flag is clear), by calling `sendResponseDown()`. 
The method only handles transient and stable versions of `I` and `S`, and the state will not change.
No response will be sent, if the state is transient or stable `I`.

Although the method calls `cleanUpEvent()` at the very end, the event is always handled in the same cycle when 
it is processed, and does not require an MSHR.

##### handleInv()

Method `handleInv()` is different from the one in the L1 cache, mainly because of the needs to recursively invalidate
upper level cache's copies. This method only handles shared, non-exclusive states.
The order between the event and a concurrent, ongoing event depends on the exact operation. The general rule is that,
if the concurrent operation also involves invalidating sharers, then the `Inv` event is ordered after the
invalidation, but before the event that initiated it, since
otherwise there will be two concurrent invalidation transactions.
In the rest of the cases, the `Inv` is ordered before the current event, and will initiate an invalidation transaction,
if one is needed.

The method uses three variables to control the execution flow. Local variable `handle` is a flag to indicate whether
invalidations are issued in the current cycle, or invalidation should be postponed or not issued. 
Local variable `state1` and `state2` are the two states to transit to, respectively, for the case where invalidation
should be issued, and the case where invalidation is not needed.

The method begins with a switch block. 
State `S`, `S_B` and `SM` blocks are essentially still in `S` state, and there is no ongoing invalidation
transaction. The `Inv` request can hence be ordered before the concurrent flush line or upgrade.
If invalidations are needed (which is checked after the switch block, for code simplicity), then they will 
transit to `S_Inv`, `SB_Inv`, and `SM_Inv`, respectively.
Otherwise, the state will be `I`, `I`, and `IM`, respectively (note that `S_B` can also transit to `I_B`, which
does not affect correctness).
Flag `handle` is also set to `true`, indicating that the event is potentially ordered before the concurrent event.

In the case of `S_Inv` and `SM_Inv`, since an invalidation is already going on, the `Inv` can only be ordered
after the concurrent event. In this case, an MSHR entry is allocated at the front entry by calling `allocateMSHR()`
with `pos` being zero. After the current invalidation completes, the `retry()` method called in `handleAckInv()`
will then schedule the current `Inv` for execution, meaning that the `Inv` is still ordered before the 
event that caused the invalidation.

In the case of transient and stable `I` states, the `Inv` will be ignored, and `I_B` will just directly transit
to `I`.

After the switch block, `handle` is checked. If `handle` is `true`, meaning that invalidations should be issued at
the current cycle, then the method further checks whether the block has any upper level sharer. If true,
then an MSHR entry is allocated at the front of the register.
If the allocation succeeds, then `invalidateAll()` is called to send invalidations to all upper level
sharers, and state transits to the one stored in `state1`.
Otherwise, if there is no sharer to invalidate (`invalidateAll()` returns `false`, but checking the line's sharer
directly should also work), then the state transits to the one in `state2`, and the `Inv` completes by
calling `sendResponseDown()` to send a `AckInv` to the lower level, plus cleaning up the MSHR entry, if any,
and schedule the next entry with `cleanUpAfterRequest()`.

##### handleForceInv()

Method `handleForceInv()` handles forced invalidation, in which case the contents of dirty blocks are also lost.
This method may be called on blocks with any state except `SB_Inv` (because `SB_Inv` can only be caused by
external events, which will not race with each other), and thus handles significantly more cases 
than the previous ones.
The logic of the function, however, is similar to the one in `handleInv()`, due to the handling of concurrent 
invalidations.

The method also uses flag `handle`, `state1` and `state2` to control the execution flow after the 
switch block. 
In the switch block, `ForceInv` on block with state `S`, `E`, `M`, `SM`, and `S_B` can be handled immediately.
If invalidation is needed, then the state transits to the corresponding `_Inv` version (`state1`). Otherwise, the 
state directly transits to `I` (`state2`).

State `S_Inv` and `E_Inv` blocks are not handled, and the method just allocates an MSHR in the front entry
of the register, such that when the ongoing invalidation transaction completes, the `ForceInv` can be retried.

State `M_Inv`, `E_InvX`, and `M_InvX` should be handled more carefully. The method first check
whether these states are caused by a concurrent `GETx` event that only performs local operations involving
the current cache and its upper level caches, without forwarding the request to the lower level, 
namely, one cache requests to read or write a block that is cached in exclusive state in another cache. 
If true, then the `ForceInv` must be ordered after this request, by calling `allocateMSHR()` with `pos`
being one.
The reason for this arrangement is that, image if the `ForceInv` is inserted into the front entry, then after the
ongoing invalidation or downgrade transaction completes, the `ForceInv` will be ordered before the `GETx` request,
sets the state to `I`, and itself completes. 
The `GETx` request will then be retried on an non-existing block, which incurs undefined behavior, because the 
`GETx` in this case does not expect a response from the lower level that can further transit `I` into a meaningful
data.

If, however, that the `ForceInv` does not race with `GETx` request, then the only possibility is that it raced with
a `FlushLine`, `FlushLineInv`, or eviction. In either case, the `ForceInv` can be ordered before the flush
or eviction, by calling `allocateMSHR()` with `pos` being zero.

Transient and stable `I` state blocks do not response to the `ForceInv`, and in the case of `I_B`, it simply transits
to `I`.

Another piece of complication comes from state `SM_Inv`, which is entered when one of the upper level caches 
issue a `GETX`, hitting the `S` state line at the current level, which incurs two concurrent transactions: 
(1) Invalidation of other sharers; and (2) Upgrade from `S` to `M` from the lower level.
The `ForceInv` cannot be simply ordered before (2) and after (1), since (1) and (2) may complete in any order, and 
additionally, even if (1) completes first, there would potentially still be a sharer of the block, which is the 
issuer of the `GETX`.
To deal with this complication, the method first inserts `ForceInv` as the front entry of the MSHR register by
calling `allocateMSHR()` with `pos` being zero. Then, the method potentially issues one more invalidation
to the issuer of the `GETX` (obtained via `getSrc()` on the MSHR front entry), by calling `invalidateSharer()`
with `ForceInv` as the custom command (this helper method will not issue the invalidation if the issuer is not
a sharer, which could happen if the upper level cache does not have a shared copy when issuing `GETX`).

This way, when invalidation completes (including those in (1) and the one just issued), the `handlerAckInv()`
function will transit the state to `SM`, and then retry the `ForceInv` method, which will 
complete the `ForceInv`, and transit the state to `IM`.
When the upgrade completes, method `handleGetXResp()` will transit the state to `M`, and retry the
`GETX` event again (since the `ForceInv` entry has been removed from the MSHR register), resulting in the 
correct behavior.

On the other hand, if the upgrade completes first, then `handleGetXResp()` will transit the state to `M_Inv`,
and retry `ForceInv`, which will just keep waiting (it is already in the MSHR, so it will not be inserted twice).
When the invalidations arrive, the `handlerAckInv()` handler further transits the state to `M`, and then
retry the `ForceInv`. In this case, the event is handled immediately, leaving the state to `I`.

The rest of the method is similar to the one in `handleInv()`. The flag `handle` is checked for immediate processing.
If the block has neither sharer nor owner, then the `ForceInv` completes immediately by calling 
`sendResponseDown()` and `cleanUpAfterRequest()`, and transiting the state to the one in `state2`.
Otherwise, `ForceInv` initiates an invalidation transaction, and transits the state to the one in `state1`.

##### handleFetchInv()

Method `handleFetchInv()` handles `FetchInv`, which is the equivalence of `handleForceInv`, except that 
dirty data will be sent down, and exclusive states will also indicate a downgrade in the `FetchResp` response message.
This method is almost identical to `handleForceInv()`, with the following exceptions:

1. If the state is `S_Inv`, indicating either a `FlushLineInv` or eviction, then the `FetchInv` is inserted into 
position one, rather than zero, i.e., the `FetchInv` is ordered after the concurrent operation, for some reason.
In this case, the lower level cache that issued the `FetchInv` should treat the `PutS` or `FlushLineInv` event
as the response to `FetchInv`.

2. If the state is `E_Inv`, indicating either a `FlushLineInv` or eviction, but never `GETx` since `GETx` will not
transit into this state (`GETX` will eagerly mark the block in all levels that process this request as dirty).

I do not know why these two cases are treated differently from those in `handleFetchInv()`, although correctness
seems to be preserved.

##### handleFetchInvX()

Method `handleFetchInvX()` handles downgrade, and hence only operates on exclusive states. 
If the state is `E` or `M`, and that there is an upper level owner, then the method recursively issues a
downgrade by calling `downgradeOwner()`, allocates an MSHR, and transits the state to the `_InvX` version.
Otherwise, the event is completed immediately by calling `sendResponseDown()` and `cleanUpAfterRequest()`,
and transiting the state to `S`.

For `_Inv` and `_InvX` versions of `E` and `M`, the method handle them similarly as in `handleForceInv()`, namely,
the downgrade is ordered after an ongoing `GETx` transaction, if the concurrent invalidation or downgrade
is initiated by `GETx`.
Otherwise, if the block has an owner, then an MSHR entry is allocated from the front entry, which orders the
`FetchInvX` before the flush or eviction that caused the state, and `FetchInvX` will be retried when the
concurrent invalidation or downgrades complete.

If the current block has no owner, then no further downgrade is needed, and the state simply transits to `S_Inv`
(note that this case can only be reached if the states are of the `_Inv` versions, since `_InvX` suggests the
existence of a upper level owner). The event completes immediately by calling `sendResponseDown()` and 
`cleanUpAfterRequest()`.

### Coherence Protocol: MESI Non-Inclusive

The third type of coherence protocol is shared non-inclusive cache, implemented by `class MESISharNoninclusive`. 
Compared with inclusive caches, a non-inclusive
cache decouples the tag bank that maintains coherence states from the data bank that maintains cache blocks, such that
while the tag bank always remain inclusive of the upper level states, such that upper level requests can still be 
handled correctly based on the inclusive MESI protocol, the data bank does not need to associate a data block
for each tag entry, and can hence be much smaller than the coherence tag bank.
In reality, this design choice reduces the storage waste by caching what has already been in the upper level caches,
which can be quite significant, if there are many of them.

#### Data And Directory Arrays

The non-inclusive cache has two major components, namely, the directory bank and the data bank. Both banks are of type 
`class CacheArray`, with the directory bank being `class CacheArray<DirectoryLine>`, and the data bank being 
`CacheArray<DataLine>`. Recall from earlier sections that `class DirectoryLine` contains coherence states including 
a sharer list, and an owner field. These states store both the state of the block and the sharing or ownership 
situation in the upper level caches. 
Meanwhile, `class DataLine` just contains a data vector, and a pointer to the corresponding directory
in the directory array.

Note that in the case of non-inclusive caches, the tag array can indicate that a block is in one of the valid states,
with the actual block missing. Here, these states are more of a notion of ownership (`E`, `M` indicate ownership)
and dirtiness (`M` indicates dirty), rather than a notion of the data block.

To ensure that coherence requests from the upper levels can still be performed correctly, the directory array
remains inclusive of the upper level contents. i.e., if an address is cached by one or more upper level
caches, the address must also exists in the directory array, the coherence states of which are maintained
properly. 
Besides, to ensure that data blocks in the current cache can be accessed properly, the directory array is 
also inclusive of the data array, and on the occasion of a directory array eviction, if there exists a 
corresponding data array entry, then both the data and directory entry should be evicted, in addition to any
upper level sharers or owner.

When a data array entry is invalidated, however, the directory entry does not have to be evicted, if eviction of the
directory entry would cause further inclusion evictions from the upper level. 
This is the scenario where the non-inclusive cache becomes truly non-inclusive. 
Normal accesses and write backs from the upper level still go through the cache, and they always cause a 
data block to be allocated, unlike some non-inclusive designs where blocks could bypass a non-inclusive cache.

On the other hand, on a data eviction, if the directory entry indicates that no copies of data exists in the upper 
level (neither sharer nor owner), the directory will also be invalidated.
**The non-inclusive cache, therefore, maintains an invariant that if a directory entry is present, then 
it is guaranteed that the corresponding data block can be obtained by requesting it from the upper level caches.**
This invariant simplifies protocol design, because as we will see later, when data is requested but not present
in the non-inclusive cache, it can always transit to a transient state dedicated to this situation, and then
issue requests to the upper level.

#### New Coherence States and Actions

Since data and directory arrays are decoupled from each other, the inclusive cache hence enables a new combination
where only the directory entry is valid, while data is not present. 
These partially cached addresses require new coherence states and actions to be added in order to properly handle
tag and data separately.

All stable and transient states from the inclusive version of the protocol are still used, and their semantics remain
the same. The directory array itself essentially act as an inclusive cache without data, for which
downgrades, invalidations will be issued to maintain coherence among upper level caches.

To deal with the new cases where data is requested by the upper level, but is not present in the data array,
the non-inclusive cache adds transient state `S_D`, `E_D` and `M_D` to indicate that an access to the data is 
required, but the cache does not have it for now. Under these states, the cache controller will issue requests to
upper levels to fetch the requested block, and when data arrives, the data slot will be allocated, and states will 
transient back to the stable state.


