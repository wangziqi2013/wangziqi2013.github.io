---
layout: post
title:  "Understanding Redis Source Code"
date:   2023-02-11 22:14:00 -0500
categories: article
ontop: true
---

## General Workflow

### Input Parsing and Dispatching

`call()` (file `server.c`) is the entry point for processing a client message. It invokes `c->cmd->proc(c)`.
`c->cmd` points to the table `redisCommandTable` in commands.c and the type is `struct redisCommand`.
The call back function for each command is also defined in `struct redisCommand` as field `proc`, i.e.,
the one called within `call()`.

`c->cmd` is set by function `processCommand()` (file `server.c`). The same function also invokes `call()` at
the end. This function assumes that `c->argv` and `c->argc` are both set by its caller. It calls `lookupCommand()`
to find the `struct redisCommand` object in the command table.

`processCommand()` is called by `processCommandAndResetClient()` (file `networking.c`). The function is further
called by `processInputBuffer()` (same file).
In `processInputBuffer()`, the command string received from the client is parsed by calling `processInlineBuffer()`.

Function `processInputBuffer()` is the core routine that converts data from the client into Redis objects.
It first creates an `sds` (Simple Dynamic String, file `sds.h/c`) object named `aux` from `c->querybuf`, which is 
the receiving buffer filled by the networking functions.
Then it parses the string object using `sdssplitargs()` and stores the vector in local variable `argv`, which is 
just an array of sds objects, each being a substring parsed from the input buffer.
Later on in the function, `c->argc` and `c->argv` are both set in a `for` loop. For every substring in `argv`,
the function creates an redis object of type `robj *` by calling `createObject()` (file `object.c`) with the 
first argument being `OBJ_STRING` and the second being the substring `sds` object.

Function `createObject()` (file `object.c`) simply creates a new `robj` object using `zmalloc()`, fills in the 
type, encoding, and reference count, and initializes its `ptr` field to point to whatever that is passed
as the second argument. In our case, the second argument is an `sds` object from the `argv` discussed above.

To complete this workflow: function `processInputBuffer()` is called by `readQueryFromClient()`. 
This function itself is registered as the read call back when a client is created in `createClient()` by calling 
`connSetReadHandler()` on the connection object.

To summarize:

`createClient()`--(register as call back)-->
`readQueryFromClient()`--(call back)-->
`processInputBuffer()`-->
`processCommandAndResetClient()`--(enters server.c)-->
`processCommand()`-->
`call()`--(via command table)-->Command handler

### Command Processing

Command process starts with the call back function registered in the command table `redisCommandTable` 
(file `commands.c`). Each command has its separate handler function which is called by `call()` in `server.c`.

We start with the simplest command `SET`. According to the command table, the `SET` command is handled by
function `setCommand()` in `t_string.c`. The function wraps over `setGenericCommand()` (file `t_string.c`), which
itself calls into `setKey()` after performing a few checks.
Note that `setGenericCommand()` accepts its `key` and `value` arguments as `robj` objects. In the case 
of `SET` commands, the key and value are from `c->argv[1]` and `c->argv[2]`, respectively.

Function `setKey()` (file `db.c`) writes the key and value into the given `redisDb` object.
The function first checks whether the key already exists in the database. If false, if calls `dbAdd()` to
create a new entry in the database and initializes the key and value as per the request. 

Function `dbAdd()` (file `db.c`) first duplicates the key object into another `sds` object by calling `sdsdup()`
on the key's raw representation (i.e., `key->ptr`). It then inserts the key into a new entry by calling `dictAddRaw()`
with the newly created key object. Finally, the value is also set to the entry by calling `dictSetVal()`.

Function `dictAddRaw()` (file `dict.c`) inserts a new entry with a given key into the dictionary object (which
is how the database is implemented). The function first computes the index of the hash bucket that the entry
should be inserted into, then creates a new entry object by calling `zmalloc()` and links the new entry into
the hash bucket `d->ht_table`, and finally sets the key value by calling `dictSetKey()` (recall that the key 
object is duplicated). 

On the other hand, `dictSetVal()` (file `dict.h`) is defined as a macro in the header file. The macro 
first checks whether the dictionary object needs the value to be duplicated (by checking if the value duplication
call back function `(d)->type->valDup` is NULL), and if true, duplicates the value object by calling 
`valDup()`.

The redisDb object passed to functions in `db.c` is the client's current database object `c->db`.
This field is initialized in `createClient()` (file `networking.c`) to be the default database, i.e., the one
on index 0. Redis identifies the databases using an integer as the index, and the object on index zero is the 
default one. A client's database object can also be changed using the `SELECT` command, which is implemented by 
`selectDb()` (file `db.c`) as simply changing `c->db` to refer to a database on a different index.

To summarize:

`call()`--(via the command table)-->
`setCommand()`-->
`setGenericCommand()`--(enters `db.c`)-->
`setKey()`-->
`dbAdd()`--(enters `dict.c`)-->
`dictAddRaw()`-->
`dictSetKey()`

### Sending The Reply

#### The Workflow

After a command is processed, the reply message is sent back to the client. Replies are generated into the client's
buffer by calling `addReply()` (file `networking.c`) with an `robj` object as the parameter.
The function first checks whether the `robj` object is of string type using macro `sdsEncodedObject()` 
(file `server.h`). If true, then the string contained in the object is added to the reply buffer by calling 
`_addReplyToBufferOrList()` with the pointer to the `sds` string and the length of the string as arguments.

Function `_addReplyToBufferOrList()` (file `networking.c`) wraps `_addReplyToBuffer()` and `_addReplyProtoToList()`.
The former is used if the reply message can fit into the client's reply buffer. Otherwise, the reply message
is added to the buffer in a linked list.

Function `_addReplyToBuffer()` (file `networking.c`) performs the copy from the reply object to the client's 
buffer (`c->buf`) using `memcpy()`. The buffer pointer `c->bufpos` is also adjusted accordingly.

To summarize:

`addReply()`-->
`_addReplyToBufferOrList()`-->
`_addReplyToBuffer()`

#### Reply Objects

Redis defines reply objects for commonly used replies, e.g., `"+OK"`. The reply objects are defined as
a `struct sharedObjectsStruct` object in `server.c`. The object is a statically declared singleton named 
`shared` in `server.c` and it contains the `robj` objects that can be used for `addReply()`.
The singleton `shared` object is populated in function `createSharedObjects()` (file `server.c`).
The function initializes the object by creating `sds` string objects using `createObject()` (file `object.c`).

### The Asynchronous Event (AE) Library 

Redis implements an Asynchronous Event Library, or the AE library, to facilitate socket-based communication.
The AE library is defined in `ae.h` and `ae.c`. At a high level, the AE library works as an event loop, which is
also the main event loop of Redis server. The event loop monitors the read and write status of file descriptors 
using blocking system calls. When one or more file descriptors become readable or writable, the loop will unblock
and the corresponding event will be handled by invoking the callback functions. The rest of Redis registers 
the file descriptors and callback handlers to the AE library such that the operation of the server can be properly 
driven.

The central data structure of the AE library is `struct aeEventLoop` (file `ae.h`) which contains information for
event handling and registration. In particular, field `events` stores an array of registered file descriptors and 
callback handlers (of type `struct aeFileEvent`). Field `fired` stores an array of file descriptors that become
readable or writable in the current iteration. 
There are also two callback functions, namely, `beforesleep` and `aftersleep`, that are registered to the event loop
object. These two functions are set during server initialization and will be called before and after the blocking 
system call, respectively.

#### The System Call Layer

The AE library is compatible with a number of system calls that monitor the status of file descriptors, including 
`evport()`, `epoll()`, `kqueue()`, and `select()`, with the preference being in a descending order 
(selected in file `ae.c` as a sequence of `#ifdef`s). In the following sections, we use `select()` as an example, but
the workflow does not really change between the system calls used.

The `select`-compatible implementation resides in `ae_select.c`. The file defines `struct aeApiState`,
which contains the file descriptor arrays to be used with `select()` system call.
The file implements three vital functions. Function `aeApiCreate()` initializes the `aeApiState` object and 
sets the `apidata` field of the event loop object to point to the initialized object.
Function `aeApiAddEvent()` adds a given file descriptor into the descriptor array, which enables the descriptor 
to be monitored by the library. Function `aeApiPoll()` invokes `select()` system call with the file descriptor array.
The system call is blocking and will return when one or more file descriptor become available, or on a timeout.
After the system call returns, the function will scan the file descriptor array to determine which of them 
have fired, and inserts them into the `fired` array of the event loop object.
The function also returns the number of fired file descriptors to the caller.

#### The Event Handling Layer

The singleton event loop object is initialized during server initialization by calling `aeCreateEventLoop()` 
(file `ae.c`), which initializes the loop object and returns it to the server. The server saves the event loop 
object in the server object field `el`.

During the operation of the server, the function `aeCreateFileEvent()` will be called to register new file descriptors
and callback handlers to the AE library. This function carries the descriptor to be registered, the callback handler
`proc` (which is a function pointer), and the argument to the callback handler `clientData` (which is the `client`
object for client sockets). Note that although only one callback handler is passed to this function, the AE Library
internally distinguishes between read handlers and write handlers (as evidenced by the `rfileProc` and `wfileProc`
fields of `struct aeFileEvent`). Consequently, the provided handler will be used as both the read and the write
handler. 

After server initialization, the server enters the main event loop by calling `aeMain()` (file `ae.c`). 
This function loops infinitely and calls `aeProcessEvents()` in every iteration.
Function `aeProcessEvents()` first invokes the `beforesleep` callback (which is registered by the server during 
initialization), then invokes `aeApiPoll()`, which may be blocked in the kernel. After the call returns, the
function then invokes the after-sleep callback `aftersleep`, and then processes fired events.
It simply scans the `fired` array, and for each file descriptor in the array, invokes its read or write 
callback handler with `clientData` as one of the arguments.
A `mask` argument is also passed to the callback handler to indicate whether the fired descriptor is ready for 
read, write, or both.

Overall, the `aeProcessEvents()` function implements the main event loop of Redis server. Redis server uses
the AE Library to multiplex between multiple clients as well as the listening socket, hence implementing the 
listening and the read path. In addition, Redis server uses the before-sleep callback mechanism of the event loop 
object to implement the write path. Reply messages to the clients are sent within the before-sleep callback
after these messages are generated into the reply buffer in last iteration's command processing.

### The Listening Path

#### Binding and Listening

Redis server listens on one or more sockets and accepts connections from the clients. 
This listening path begins in function `initServer()` (file `server.c`) by calling `listenToPort()`.
The function `listenToPort()` (file `server.c`) accepts a list IP addresses to bind to and a single port number.
For every address, it invokes `anetTcpServer()` (file `anet.c`) to bind the address.
The function `anetTcpServer()` wraps over `_anetTcpServer()` (file `anet.c`), which creates a new socket
for listening by invoking the system call `socket()` followed by `anetListen()` (file `anet.c`).
Function `anetListen()` simply invokes system calls `bind()` and then `listen()` to bind the address
and start listening.
Finally, the newly created file descriptor is returned to the caller.
Note that Redis also supports other types of sockets, such as IPv6 and TLS, but we assume IPv4 sockets are
used to simplify the discussion.

To summarize:

`initServer()`-->
`listenToPort()`--(enters `anet.c`)-->
`anetTcpServer()`-->
`_anetTcpServer()`-->
`anetListen()`--(enters kernel)-->
`bind()` and `listen()`

#### Accepting New Connections

Later on during server initialization, the listening sockets are registered to the AE Library for monitoring.
The path begins with `createSocketAcceptHandler()` (file `server.c`), which calls `aeCreateFileEvent()` to
register the listening sockets one by one with the callback handler being `acceptTcpHandler()`.
The callback handler `acceptTcpHandler()` (file `networking.c`), as discussed above, will be invoked
when the AE Library fires it.
The handler calls `anetTcpAccept()` (file `anet.c`), which wraps `anetGenericAccept()` (file `anet.c`).
The latter accepts the connection by invoking the `accept()` system call.
The newly assigned socket for communicating with the client is also returned to the caller for later usage.

To summarize:

`initServer()`-->
`createSocketAcceptHandler()`--(enters `ae.c`)-->
`aeCreateFileEvent()`--(via callbacks, enters `networking.c`)-->
`acceptTcpHandler()`--(enters `anet.c`)-->
`anetTcpAccept()`-->
`anetGenericAccept()`--(enters kernel)-->
`accept()`

#### Creating the Connection Object

After the connection is accepted at the OS level, the next step is to initialize the local data structures for
keeping the client's information. This path begins in function `acceptTcpHandler()` (file `networking.c`) by
calling `connCreateAcceptedSocket()` (file `connection.c`). The function wraps `connCreateSocket()` 
which allocates a new connection object of type `struct connection`.
The connection object represents the server-side state of the connection. The object stores the file descriptor
returned from `accept` system call. The object also contains two critical callback handlers, the `read_handler`
and the `write_handler`, which are invoked for reading and writing data from/into the socket. 
The `type` field of the connection object defines a series of function pointers that either operate on the 
connection object itself or on the socket. For example, `type->set_read_handler` assigns a new read handler
to the connection object's `read_handler` field, while `type->read` directly reads the socket using the `read` system
call. The newly allocated connection object is returned to the caller for later usage.

To summarize:

`acceptTcpHandler()`-->
`connCreateAcceptedSocket()`--(enters `connection.c`)-->
`connCreateSocket()`

#### Creating the Client Object

After creating the connection object, the Redis server then proceeds to creating the client object.
This path also begins in `acceptTcpHandler()` right after the connection object is returned. 
The returned object is passed into function `acceptCommonHandler()` (file `networking.c`), which first 
checks whether the connection is valid and legal (e.g., not exceeding the maximum number of concurrent
connection), and then calls `createClient()` to create the client object.

Function `createClient()` (file `networking.c`) first creates a `struct client` object using `zmalloc()` 
and then sets the read handler of the connection object for the client to `readQueryFromClient` by calling 
`connSetReadHandler()`. 
Finally, the function initializes the client's states including the send and receive data buffer and buffer
pointers. The database object that the client operates on is also set to the default one on index zero by
calling `selectDb()`.

Function `connSetReadHandler()` (file `connection.c`) will indirectly call `connSocketSetReadHandler()` via the
per-connection object `type` field. 
Function `connSocketSetReadHandler()` (file `connection.c`) stores the callback handler in the connection
object's `read_handler` field and then registers the file descriptor of the connection to the AE Library
via `aeCreateFileEvent()`. 
The registered callback handler to the AE Library is function `connSocketEventHandler()` (file `connection.c`),
which will in turn call `read_handler` and/or `write_handler` fields when the file descriptor fires in the AE Library. 

Overall, during the client creation process, the file descriptor of the client is registered to the AE Library
for monitoring. The callback handler `readQueryFromClient` will be invoked (after several levels of indirection)
when the file descriptor is read to be read. Note that the client does not register any write handler to the 
connection to the object. As a result, the connection is only capable of reading from the client but
not vise versa.

To summarize:

`acceptTcpHandler()`-->
`acceptCommonHandler()`-->
`createClient()`--(enters `connection.c`)-->
`connSetReadHandler()`-->
`connSocketSetReadHandler()`--(enters `ae.c`)-->
`aeCreateFileEvent()`--(via callback, enters `networking.c`)-->
`readQueryFromClient()`-->

### The Read Path

As discussed earlier, when a client is initialized, its file descriptor is registered to the AE Library for read.
The callback handler of the registration is function `readQueryFromClient()`, meaning that
this function will be invoked every time some data arrives at the socket and is selected by the AE Library.
The handler will be invoked with the connection object as its sole argument, which is passed to the 
AE Library at registration time.

Function `readQueryFromClient()` (file `networking.c`) first checks whether the buffer is big enough for the client
message. In most cases, no action is taken, and the function then calls `connRead()` on the client's connection object.
Inline function `connRead()` (file `connection.h`) indirectly calls `connSocketRead()` via the connection
object's `type->read`, which in turn invokes the `read()` system call to pull data out of the socket stream.
Note that the destination buffer of the read is the client's `querybuf`, which is coupled with `qblen` to indicate
the current length of data in the buffer. 
The length to be read is calculated as the remaining capacity of the buffer, as evidenced by the 
local variable `readlen`.

After data is read from the socket, the handler then invokes `processInputBuffer()` to parse and dispatch 
the command. We have already covered the command parsing and dispatching in an earlier section.

To summarize:

`readQueryFromClient()`--(enters `connection.c`)-->
`connRead()`-->
`connSocketRead()`--(enters kernel)-->
`read()`

### The Write Path

After the Redis server processes the command, the reply is generated into the client's reply buffer by calling 
`addReply()`. The function eventually copies data in the reply message to the client's reply buffer `c->buf`, which
is coupled with `c->bufpos` to indicate the current write position.

In order to send the reply message back to the client, the Redis server, during initialization, registers a callback 
function to the AE Library as the before-sleep callback via `aeSetBeforeSleepProc()`. The callback function 
being registered is `beforeSleep()`.

Recall that the before-sleep callback, i.e., function `beforeSleep()` (file `server.c`), is invoked right before 
the AE Library invokes `select()` (or other multiplexing system calls). 
The function invokes `handleClientsWithPendingWritesUsingThreads()` (file `networking.c`) whose name may be somehow
misleading because Redis, by default, is not multi-threaded.
However, after a careful examination of the function body, it turns out that the function simply wraps over 
`handleClientsWithPendingWrites()` if multi-threading is disabled (by checking `server.io_threads_num`, a
configuration variable defined in `config.c`).

Function `handleClientsWithPendingWrites()` (file `networking.c`) traverses the list `server.clients_pending_write`,
which contains clients that have reply messages to send. This list is populated at the beginning of `addReply()` by
calling `prepareClientToWrite()` (file `networking.c`).
For every client in the list, the function calls `writeToClient()`, which wraps over `_writeToClient()`.
Function `_writeToClient()` (file `networking.c`) further calls `connWrite()` on the client's connection
object, which indirectly calls `connSocketWrite()` via the connection's `type` field.
The write path terminates at function `connSocketWrite` (file `connection.c`), which invokes the `write()` system
call on the connection's file descriptor. Note that `connWrite()` might be invoked several times for a single buffer
due to `write()` not being able to accept the requested length (which is completely normal).

To summarize:

`beforeSleep()`--(enters `networking.c`)-->
`handleClientsWithPendingWritesUsingThreads()`-->
`handleClientsWithPendingWrites()`-->
`writeToClient()`-->
`_writeToClient()`--(enters `connection.c`)-->
`connWrite()`--(enters kernel)-->
`write()`-->

## Data Structures

### The Dict Object

Dictionary objects lie at the core of Redis as the database itself is implemented as a `struct dict` object.
The struct is defined in `dict.h` and implemented in `dict.c` and it is quite simple. 
The `dict` object merely implements a standard chained hash table with incremental rehashing.

#### The Data Structure

Entries in the `dict` object is implemented as `struct dictEntry` objects. The object contains a key pointer,
a value field that can be a pointer, an integer, a floating point number, etc, and a metadata field. 
The definition of the metadata field depends on the type of the `dict` object and it makes the `dictEntry` 
variable-sized. However, the metadata field is largely irrelevant to the operation of the `dict` object.
The `struct dictEntry` objects in the same bucket are linked together as a linked list via the `next` pointer.

The `dict` object contains two instances of hash tables, stored in fields `ht_table`, `ht_used`, and `ht_size_exp`.
Field `ht_table` stores two copies of the bucket array, with each bucket being a pointer to a linked list
of `struct dictEntry` objects. Field `ht_used` tracks the number of entries in each of the two hash tables.
Field `ht_size_exp` stores the log2 of the sizes of the `ht_table` array (hash table sizes are always powers of two).

#### Incremental Rehashing

When the number of entries exceeds a certain threshold (currently when the load factor grows above 1, or when
rehashing is disabled but the load factor grows above 5), the hash table in the `dict` object will be resized
via the rehashing operation. The rehashing operation iterates over entries in the first instance of the hash
table (on index 0) and moves them to the second instance of the hash table (on index 1). 
If a rehashing is going on, insert operations will directly insert the new key into the second instance. 
Read operations, on the contrary, have to check both hash tables because the entry can reside in either of them
depending on the rehashing progress.

Rehashes are triggered by function `_dictKeyIndex()` which computes key hash values. The function calls 
`_dictExpandIfNeeded()` to check for rehashing conditions. If the load factor of the hash table exceeds the 
threshold, it will call `dictExpand()` to initiate the rehashing. The size of the new table is twice as large
as the previous one as evidenced by the second argument passed to `dictExpand()`, i.e., `d->ht_used[0] + 1`.

Function `dictExpand()` simply wraps over `_dictExpand`. The latter allocates the bucket array of the second hash 
table instance by calling `zcalloc()` and assigns it to `d->ht_table[1]`. In addition, the `ht_used` field is set
to zero, and the `ht_size_exp` field is set to the log2 of the new size. Finally, the function sets `d->rehashidx`
to zero, indicating that a rehashing is in progress. The value will be reset back to `-1` after the rehashing
completes.

On basically every hash table operation, the macro `dictIsRehashing()` (file `dict.h`) is called to check if the table 
is currently under rehashing. The macro simply checks whether `d->rehashidx` is `-1` or not.
If rehashing is in progress, then the function `_dictRehashStep()` is called to incrementally rehash a few 
buckets from the first hash table to the second one.

Function `_dictRehashStep()` wraps over `dictRehash()`. The latter rehashes entries by removing them from the first
hash table and inserting them into the second hash table, with the values of `d->ht_used` being adjusted accordingly.
The function returns when the first hash table becomes empty, or when `n * 10` buckets have been rehashed in the
current invocation. The field `d->rehashidx` stores the next index of the bucket to be rehashed and is hence 
incremented for every rehashed bucket.

Rehashing is completed when `d->ht_used` for the first table drop to zero. In this case, the second hash table is
moved to the first table's slot, and the first table is deallocated by calling `zfree()`.
Field `d->rehashidx` is also reset to `-1` such that no rehashing will be attempted.

#### Dict Operations

The lookup operation on the `dict` object is implemented in `dictFind()`. This function first calls `dictHashKey()`
to compute the key hash value, then uses the hash value to find the bucket, and finally walks the entry linked
list of the bucket and compares hash values and keys against the entries.
Note that if rehashing is in progress, then both hash table instances will be checked. Otherwise, only the 
first instance is checked.

The insert operation is implemented in `dictAddRaw()`. This function first checks whether the key already
exists (in both tables) by calling `_dictKeyIndex()`. `_dictKeyIndex()` returns the index of the bucket on the
first hash table if no rehashing is in progress, or returns the index on the second hash table otherwise.
Besides, the key will not be inserted if it already exists in any of the two tables.
If the check passes, a new entry object is allocated and linked to the head of the bucket.

Deletion is implemented in `dictGenericDelete()`. This function locates the bucket using the hash value,
walks the linked list, and unlinks the entry from the list if the hash value and key match. 
The function also takes an argument, `nofree`, which indicates whether the entry unlinked from the dictionary 
should be freed or not. If the caller needs the deleted entry (as is the case with `dictUnlink()`) then this
value should be set to `1`. Otherwise it is set to zero, as in `dictDelete()`.

More complicated operations are also available on the `dict` object. However, these composite operations are 
just combinations of the above three primitives and can be easily understood.

#### Dict Types

Every `dict` object also has a type object of type `struct dictType` which is accessed via `d->type`. 
The type object consists of function pointers to handle a certain key and value types. 
For example, `hashFunction` defines the hash function for the key type.
`keyDup` and `keyDup` define the duplication function for keys and values. These two callbacks are used
by `dictSetKey()` and `dictSetVal()` macros to duplicate the key and value (if one is provided).
Similarly, `keyDestructor` and `valDestructor`, when provided, are used to deallocate keys and values when entries
are deallocated.

### The Database Object

#### Initialization

The database object is the top-level data structure in Redis which maps keys to values. 
Database objects are initialized when the server is initialized in `initServer()` (file `server.c`). 
Users could specify the number of databases in the configuration file using `databases` option. This option
is registered in the options table `configs` (file `config.c`), and when the configuration is applied, it
sets `server.dbnum` field to the value given by the user (default to 16 otherwise).

During initialization, the databases are created as an array of `redisDb` objects using `zmalloc()` and stored in 
`server.db` field. Later in the same function, the databases are initialized. In particular, 

#### Selection

Each client is assigned a database when created, which is a reference to the database object in the server object. 
By default, Redis assigns database zero to each newly created client
in `createClient()`. In addition, clients can also switch database using the `SELECT` command, which is handled by
the `selectCommand()` function (file `db.c`). The function parses the only argument as the database index and then
invokes `selectDb()` to change the client's current database reference.

#### Database Type

The database object contains a `dict` instance for key-value mapping, with the type being `dbDictType` (file `server.
c`). The type object has all callbacks being set except key and value duplication functions, meaning that when
a key-value pair is inserted into the database, the function that inserts it must duplicate the object if necessary.
Besides, database value objects are reference counted, as indicated by the destructor callback function
`dictObjectDestructor()` (file `server.c`). This function calls `decrRefCount()` (file `object.c`) on the value object.
If the reference count drops to zero, `decrRefCount()` will then deallocate the value object based on its type using
a switch block.

Key objects, on the contrary, is not reference counted. The destructor callback function for database keys is
`dictSdsDestructor()` (file `server.c`), which simply deallocates the key string object by calling `sdsfree()` (file 
`sds.c`).

### The Simple Dynamic String (SDS) Library

Redis encapsulates strings and binary data into a data type called the `sds` type. `sds` is an efficient
and compact library for representing strings and arbitrary binary data. The implementation is in `sds.h` and `sds.c`.

#### Memory Layout

The `sds` type objects are referred to using the type name `sds`, which, surprisingly, is typedef'ed as `char *`. 
An `sds` type pointer, therefore, points to the beginning of the null-terminated string. 
However, compared with the standard C language strings, the `sds` object also has a header that is located *before*
the `sds` pointer. The header stores the length and the allocated buffer size of the string and can be accessed
by moving the pointer *forward*.

An `sds` header consists of three fields, i.e., a `len` field storing the length of the string (excluding the 
terminating `'\0'`), a `alloc` field storing the size of the allocated buffer (excluding the terminating `'\0'`),
and a `flag` field storing the header type.
Headers can be one of the four types, namely `sdshdr8`, `sdshdr16`, `sdshdr32`, and `sdshdr64`. These four types
differ from each other by using different integer types for the `len` and `alloc` fields. 
The 8-bit `flag` field is placed at the end of the header and is therefore can be accessed via the `sds` pointer by
subtracting one from it (e.g., `sds[-1]`). The `flag` field stores the header type, which must be read first in order 
to determine the size of the header.

Macro `SDS_HDR()`, given an `sds` pointer and the header type, returns the pointer to the header. 
Macro `SDS_HDR_VAR()` is translated into a variable definition of name `sh`, which points to the header of the given 
`sds` object.

#### SDS Object Creation

`sds` objects are created by calling `sdsnewlen()` or `sdstrynewlen()`, both wrapping the actual creation function 
`_sdsnewlen()`. Function `_sdsnewlen()` takes a pointer to the string or binary data, the length of data, and a flag
`trymalloc` indicating whether `malloc()` failure should cause a panic.
The function first computes the type of header to use by calling `sdsReqType()`. For shorter strings, we can encode
its length and allocated buffer size with smaller integers, and therefore, the shorter header can be used to save
space. It then allocates the storage for the `sds` object by calling `s_malloc_usable()`. 
The allocated size is the data size, plus header size, plus the trailing zero, although `malloc` may return
a slightly larger buffer due to binned allocation, which is put in `usable`.
Then the header is initialized with the length of data and the allocated size.
Finally, the data is copied into the buffer using `memcpy()`. The `sds` type pointer is returned back to the
caller. The pointer can be directly used as a C language string without any typecast or pointer arithmetic.

The SDS library also implements common string operations such as string copy, concatenation, trimming, etc. Their
implementations are rather straightforward. Besides, the library provides functions to convert other types into 
`sds` objects, e.g., `sdsfromlonglong()`, and to print into an `sds` object from a format string just like
`snprintf()`.

### Linked List

Redis contains a standard doubly linked list implementation in file `adlist.h` and `adlist.c`. The source code is 
simple and easy to understand with very little to cover. However, it is worth noting that Redis's linked list
object carries three callback functions, namely, `dup`, `free`, and `match`. These three functions will duplicate,
deallocate, or compare for equality on the value object (`value` field of each node), respectively.
As a result, the list object can be duplicated, deallocated, and searched for a particular key using the interface 
functions `listDup()`, `listRelease()`, and `listSearch()`.

## Build, Compilation, and Usage

### Disabling Persistence

Redis has two independent persistence mechanisms: RDB and AOF. RDB uses copy-on-write (implemented in the OS kernel
via `fork()`) to capture a consistent memory snapshot and save it to the disk. AOF (Append-Only File) is similar 
to write-ahead logging and it writes committed operations to a log file on the disk.
Besides, when Redis exits via Ctrl-C, it will also save the dump of the database as `dump.rdb` in the current 
working directory.

In order to disable persistence entirely, pass the following command line options to `redis-server`:

```
./redis-server --save "" --appendonly no
```

The first `--save` option followed by an empty string disables RDB snapshotting. The second `--appendonly` option 
disables AOF.

### Adding New Source Files

Redis has a rather clear and simple make system. In order to add a new source file for compilation, 
first you should create the file under `./src` directory. Then update the `Makefile` under `./src` by adding the object
file name to the list named `REDIS_SERVER_OBJ` (assuming the file is part of the server).
