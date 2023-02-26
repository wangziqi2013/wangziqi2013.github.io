---
layout: post
title:  "Understanding Redis Source Code"
date:   2023-02-11 22:14:00 -0500
categories: article
ontop: true
---

## The Redis Serialization Protocol (RESP)

Newer versions of Redis employ RESP (Redis Serialization Protocol) to transfer requests and responses as 
binary strings. From a high level, RESP provides an easy-to-implement specification for 
representing common data types such as strings, integers, arrays.
In RESP, strings are represented as a `$` character, followed by the length of the string in decimal format, 
followed by `\r\n`. The string itself can contain arbitrary characters including `\0`, `\r` and `\n` and can
hence be used to represent binary blobs.
Integers are represented as a `:` character, followed by the decimal representation, followed by `\r\n`. 
Arrays are represented as a `*` character, followed by the number of elements of the array in decimal
format, followed by `\r\n`. The elements of the array then follows the array header, which themselves can be
of any of the valid data types.

Both Redis requests and responses are encoded by RESP before they are sent over the connection. For requests, 
the RESP format is always an array of strings, with the first string being the command and the rest of them
being the arguments. Responses, however, can be of any valid RESP data type. The most common form of a reply 
is a string beginning with either `+`, indicating that the command has executed successfully, or `-`, 
indicating that the command failed to execute.

## The Asynchronous Event (AE) Library 

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

### The System Call Layer

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

### The Event Handling Layer

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

## General Workflow

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

### Command Parsing and Dispatching

#### The State Machine

Requests are read by a state machine over potentially multiple attempts to read from the connection, due to the 
fact that a request may not be fully received with a single read operation, especially the long ones.
Redis maintains a few state variables in the `struct client` object (defined in file `server.h`). 
The first is `multibulklen`, which is the number of elements in the request RESP array.
The second is `bulklen`, which is the length of the current RESP string being received.
The struct member `querybuf` is an SDS type string used as the per-connection receiving buffer, with the 
member `qb_pos` as the current head of command parsing. The length of the SDS string, on the other
hand, represents the current size of data in the receiving buffer.

The received RESP string objects are stored temporarily in the `argv` field of the client object as an array 
of `robj` objects, with the `argc` field indicating the current number of arguments that are already parsed. 
The total number of elements in the `argv` field is indicated by the value of `multibulklen`.

#### Reading from the Connection

The input parsing workflow begins with function `readQueryFromClient()` (file `networking.c`), which is registered
to the AE library as the call back function of the connection and will be invoked when the socket is ready to be read.
In the most common case, this function 
first attempts to allocate at least `PROTO_IOBUF_LEN` bytes in the receiving buffer by calling `sdsMakeRoomFor()`,  
and then computes the number of bytes to read, `readlen`, by calling `sdsavail()` on the query buffer object 
`c->querybuf`, which returns the number of available bytes after the current valid content in the allocated memory 
block for the buffer. 

After the buffer is set up, the function calls `connRead()` to actually read from the connection. The `connRead()`
function indirectly invokes `connSocketRead()` (file `connection.c`), which in turn invokes the `read()` system
call on the socket descriptor. The return value from the `read()` system call is also relayed back to the caller
as local variable `nread`.

After the read call returns, the function first checks the return value for any anomalies (both `0` and `-1` 
indicate anomalies). Then the size of the receiving buffer is updated by calling 
`sdsIncrLen`, which increases the length of the string object by `nread` bytes.
Lastly, the function `processInputBuffer()` is called to parse the received content in the buffer. 
This function may return `C_ERR` to indicate a parsing failure. 
If a failure occurs, the function call to `beforeNextClient()` will close the connection and deallocate the 
client object, hence terminating the current session.

#### Parsing Command Header

Function `processInputBuffer()` (file `networking.c`) is called every time new data is received from the 
connection, which is is responsible for parsing command data and driving the state machine.
This function starts parsing from `c->qb_pos` until the buffer is drained.
It first checks whether `c->reqtype` is zero or not. If it is zero, indicating that the function is currently
parsing a new command rather than in the middle of parsing, then it determines whether the command is
a multiblock one (i.e., using RESP) or an inline command by checking whether the first character of the buffer
is `*`. In the case of RESP, the request type field of the client object is set to `PROTO_REQ_MULTIBULK`.
For RESP format requests, the function then calls `processMultibulkBuffer()` to parse the RESP strings.
If the command is fully received, then function `processMultibulkBuffer()` will finish parsing and return `C_OK`, 
after which the command is executed by calling `processCommandAndResetClient()`. 
Otherwise, the command cannot be parsed because more data is to be received.
In either case, the receiving buffer is truncated by calling `sdsrange()` (file `sds.c`), which shifts the 
unparsed content of the buffer after `c->qb_pos` to the beginning, preparing the buffer for the next receiving 
operation. The client object's `qb_pos` field is also reset to zero to indicate that future parsing will start from 
the first byte of the buffer.

Function `processMultibulkBuffer()` (file `networking.c`) implements RESP parsing. 
The function first checks whether `c->multibulklen` is zero. If true, then a new command is being parsed, in
which case the function reads the number of elements in the array by first verifying that a `\r` exists 
in the receiving buffer (meaning that the array header has been fully received), and then parsing the 
number of elements by calling `string2ll()` (file `util.h`) to convert the decimal representation in the array header
to an integer.
After the array size is parsed, the value is stored in `c->multibulklen`, and `c->argv` is initialized accordingly.
Future invocations of this function will see a non-zero value for `c->multibulklen`, in which case it knows that
the state machine is currently in the middle of parsing a partially received command and will therefore skip
the above step. 

#### Parsing Command Data

After parsing the header, the function then proceed to parse the array element one by one, using `c->multibulklen`
as the loop control variable. For every element, the loop checks whether it begins with `$`, then parses the 
length of the RESP string using `string2ll()` after verifying the `\r` character, and finally reads the string 
into a newly allocated SDS object. The SDS object is wrapped by an `robj` object and then put into `c->argv`. 
At the end of the loop, `c->multibulklen` is decremented by one to indicate that one element has been successfully 
parsed.

However, simple as it seems, the parsing code must also take one possible scenario into consideration, i.e., when
the element is too big to be fully received by one `read()` call. In this scenario, multiple invocations to the 
receiving function have to be made in order to fully receive the element before copying it to the argv as an SDS 
string. More specifically, the parsing function uses `c->bulklen` to store the remaining length
of the current string element to be read after the length is parsed from the receiving buffer. 
Then in the next iteration of `readQueryFromClient()`, the `c->bulklen` will be used to determine the size of the 
receiving buffer such that the buffer can always hold the element in its entirety.
The parsing function will not process the element before it is fully received.

After the element is fully received, the function `processMultibulkBuffer()` then allocates a new SDS string object
and wraps it with a `robj` object by calling `createStringObject()` with the pointer to the receiving buffer and 
the length of the element as arguments.
The function also implements an optimization here, i.e., if the length of the element exceeds a certain threshold
(`PROTO_MBULK_BIG_ARG`) and the receiving buffer only contains the element's data, then the receiving buffer
will be directly used as the SDS string without redundantly copying its content to a newly created string object. 
In this case, a new receiving buffer will be created and assigned to the client object.

After fully receiving an element, the `robj` object will be inserted into the client object's `argv` array,
and `c->argc` is incremented by one to indicate that one more element has been parsed.
At the end of the parsing loop, `c->bulklen` will be set to `-1` to indicate that the state machine is not
in the middle of receiving an element, and `c->multibulklen` is decremented by one.
If `c->multibulklen` drops to zero after decrementing, then the command has been fully parsed, in
which case the function returns `C_OK` to notify the caller that the command can be processed.

To summarize:

`readQueryFromClient()`-->
`processInputBuffer()`-->
`processMultibulkBuffer()`

#### Inline Requests

Alternatively, requests can be sent to and processed by the Redis server in an inline format where the command 
and the arguments are separated by one or more space characters and is terminated by the new line character `\n`. 
The inline request format is more human readable and favors manually generated requests via command line tools 
such as `telnet`.

When processing a new command from the client, the Redis server distinguishes between RESP format and inline format
by checking whether the first character of the request is `*` or not. In the latter case, the function 
`processInlineBuffer()` is invoked to process the request as an inline request.

Function `processInlineBuffer()` (file `networking.c`) first verifies that the entire command has been received in
the buffer by checking whether `\n` is in the buffer. Note that Redis cannot determine the length of the 
inline request if the request is not fully received, and hence will always report error back to the client
if the `\n` is not found. In other words, inline requests cannot be received over multiple `read()` attempts
and is therefore not recommended for usages beyond manual testing.

If the `\n` is found, then the function first creates a new SDS string object `aux` that only
contains the content of the inline request from the receiving buffer, and then
calls `sdssplitargs()` to split `aux` into an local `argv` vector containing substrings separated by space characters.
The function then initializes `c->argc` and `c->argv` with newly created `robj` objects wrapping the substrings 
in the local `argv` vector.

To summarize:

`readQueryFromClient()`-->
`processInputBuffer()`-->
`processInlineBuffer()`

#### Command Dispatching

After receiving and parsing the command, the client object's `argc` and `argv` are set to the number of arguments 
(including the command itself) and the substrings containing argument data, respectively.
In this case, the parsing function returns `C_OK` to the caller function `processInputBuffer()`, and 
the command is processed by calling `processCommandAndResetClient()`, which in turn calls `processCommand()`. 

Function `processCommand()` (file `server.c`) implements the command dispatching logic as follows.
The function first looks up the in-memory command dictionary by calling `lookupCommand()`, which searches the
structure using the first element of the client object's `argv` vector as the key. 
The in-memory command dictionary is initialized from the statically defined global variable `redisCommandTable`
(file `server.c`) during server initialization by calling `populateCommandTable()`.
The in-memory command dictionary is implemented as a `dict` object in the server object as a field named `commands`.
During initialization, function `populateCommandTable()` traverses the table `redisCommandTable`, and for every
table entry, inserts it into the in-memory command dictionary using the command name as the lookup key.

Function `lookupCommand()` (file `server.c`) simply wraps `lookupCommandLogic()`, which in turn calls 
`dictFetchValue()` on `server.commands` to look up the in-memory command dictionary.
If the command is found, it will be returned back to the caller
function `processCommand()` as a pointer to the `struct redisCommand` object and assigned to the `cmd`
field of the client object.
The function then performs command integrity checks such as the number of arguments (the arity check),
sets a few flags according to the command's statically-defined properties, and checks the permissions.
If any of the checks fails, the server will reject the command and send an error message back to the
client by calling `rejectCommand()`.
At last, after all checks have passed, the command is executed by calling `call()` on the client object.

Function `call()` (file `server.c`) performs a large number of extra checks based on the runtime 
flags of the command and the server configuration. However, the most critical line of the function is the line that
invokes `c->cmd->proc()`, which is the command handler registered to the `struct redisCommand` object.
The command handler implements the specific command that corresponds to the command string in the request.
Individual command handlers can be easily located in the global table `redisCommandTable` residing in file 
`server.c`.

To summarize:

`processInputBuffer()`-->
`processCommandAndResetClient()`--(enters `server.c`)-->
`processCommand()`-->
`call()`--(via callback)-->
`c->cmd->proc()`

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

### Configuration

#### Specifying the Configurations

Redis server configuration is set up during server initialization. Configuration capability is implemented in 
file `config.c`. The file contains a configuration table named `configs`, which stores all configurations. 
The element of the `configs` table is of type `struct standardConfig`, which consists of a `name`, an `alias`,
`flags`, and two type-dependent objects. Both `name` and `alias` are the names that can be used as the option key. 
The type-dependent objects, namely `interface` and `data`, define the data storage of the configuration
value and the interface functions for setting, getting, and initializing the configuration options. 
In particular, the `data` object contains a pointer to the location that the configuration value should be written
to after they are read. It also contains the default value of the configuration in the case it is not explicitly
given.

The `configs` table is just an array of `struct standardConfig` objects where configurable options are defined 
using the pre-defined macros. The macros are straightforward to use and the existing table is a good reference.

#### Reading Configuration Options

Redis server supports two forms of configuration. Either it is provided via a configuration file, or it is 
directly given in the command line option. In the former case, the file should be organized into lines, where
each non-empty line not starting with `#` specifies the value of a configuration option. 
The first token of the line (character string ending with a space) is treated as the option key, and the rest of 
the line is treated as the value. In the case of command line options, the option key is given by prefixing 
the key with `--`, and the option value follows the key. Multiple values can be given for a single key, 
with space characters separating them. These command line values will be concatenated to form the actual value during
server initialization

The server reads the configuration options in three stages.
In the first stage, it initializes all options defined in the `configs` table to their default values by calling 
`initServerConfig()` (file `server.c`) in the main function. This function in turn calls 
`initConfigValues()` in file `config.c`, which simply iterates over all configuration entries in the `configs` 
table and writing the default value to the pointer stored in the entry (which all points to the fields of the 
singleton server object).
Function `initServerConfig()` also sets the default value for non-configurable fields in the server object by directly 
assigning to them.

Then in the second stage, the main function of the server parses the command line options.
If the configuration file name is given, it must be the first argument (i.e., `argv[1]`). Otherwise, all command
line options will treated as options keys and values. The server iterates over the `argv` vector, treating every
entry that begins with `"--"` as keys, and those between keys as values belonging to the former key.
The parsed keys and values are concatenated to an `sds` string, such that each line of the string represents 
a configurable option. As mentioned earlier, if multiple values are specified for a key, all the values will be 
concatenated and appear on the same line, separated by a space.

To summarize:

`main()`-->
`initServerConfig()`--(enters `server.c`)-->
`initConfigValues()`

#### Parsing Configuration Options

In the final stage, the main function invokes `loadServerConfig()` (file `config.c`), passing the configuration
file name (if given) and the `sds` string parsed from the command line options as an argument.
The function will first search for the file (or files, if the file name is a regular expression), then
read the file, and concatenate the `sds` string storing the command line options to the file content. 
Since options given by the command line are processed after those in the configuration file, the command line
options have higher priority and can hence override those in the configuration file.

The combined `sds` string containing the configuration file content and command line options are then passed to 
function `loadServerConfigFromString()` (file `config.c`). The function parses the string by first splitting it
into lines using `sds` utility function `sdssplitlen()`. Then the function splits each individual line that
is not empty nor begins with `#` into tokens using `sdssplitargs()`.
Next, the function searches the `configs` table to lookup the option key, which is the first token of the line.
If the configuration entry is found in the table, the value is set by calling `interface.set()` of the entry.
The setter function will convert the value or values into the correct type and then write them to the pointer
stored in the configuration entry.

To summarize:

`main()`--(enters `server.c`)-->
`loadServerConfig()`-->
`loadServerConfigFromString()`

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

The database object contains a `dict` instance for key-value mapping, with the type being `dbDictType` 
(file `server.c`). The type object has all callbacks being set except key and value duplication functions, meaning 
that when a key-value pair is inserted into the database, the function that inserts it must duplicate the object if 
necessary. Besides, database value objects are reference counted, as indicated by the destructor callback function
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

### Intset

Redis implements sorted integer set in file `intset.h` and `intset.c`. Overall, the `intset` structure is just an
array of integer elements stored compactly in sorted order. Lookup operations on the set involve binary search to
locate the position of the given search key. Insertion operations need to shift the elements backwards if the 
key to be inserted is to be inserted into the middle of the element array.

Simple as it is, there are, however, several implementational highlights. First, the `intset` object implements three
different element sizes, namely, 16-bit, 32-bit, and 64-bit integers. At any given moment, all elements must be of 
the same size, hence necessitating upgrade conversions between types when an element is inserted and the element 
cannot be represented in the current type. There is no downgrade, though, as an `intset` element will remain in
the upgraded type even if all elements can be represented with shorter integers.
Second, Redis performs endian conversion on both `intset` internal metadata and the set elements when they are
read from and written into memory. The endian conversion is to maintain compatibility between small- and big-endian
architectures when a database is dumped on one architecture and loaded back into the memory on another 
architecture with different endianness. Fortunately, Redis internally adopts small-endian representation for all
data and metadata, meaning that the endianness conversion on x86 architecture is merely no-ops. To verify this
claim, check out the endianness conversion macros and functions in `endianconv.h` and `endianconv.c`.
Accordingly, the macros `intrev32ifbe()` and `memrev16/32/64ifbe`, which are heavily used in 
the `intset` implementation, can be safely ignored as no-ops.

#### Layout

The `intset` object contains only two fields. Field `encoding` stores the current element size, the value of which
can be one of the `INTSET_ENC_INT16`, `INTSET_ENC_INT32`, and `INTSET_ENC_INT64`. Field `length` stores the current 
number of elements in the set.
The element array follows the two fields and it fills the rest of the object. Note that the `intset` object itself
is also variable-sized due to having the element array at the end.

#### Operations

An `intset` object is created via `intsetNew()`, which initializes an object with zero element.
Lookup operations use `intsetFind()`, which calls into `intsetSearch()` to perform the binary search.
Insert operations use `intsetAdd()`. This function first checks whether the newly inserted value can be 
represented with the `intset`'s current type. If negative, the function calls `intsetUpgradeAndAdd()` to
first upgrade the set and then inserts the element. Function `intsetUpgradeAndAdd()` in turn calls 
`intsetResize()`, which uses `realloc()` to expand the memory block of the current `intset` object. 
The function then type casts all the existing elements in the element array to the upgraded size.
Otherwise, the element can be directly into the `intset` without any conversion. In this case, the 
insert function calls `intsetSearch()` to locate the insertion point via binary search, then calls 
`intsetResize()` to potentially expand the `intset`'s memory block (it is essentially abusing `malloc` library's
allocation size feature), and finally inserts the element into the array after shifting the existing 
elements using `intsetMoveTail()` to make room for it.
Deletion operations using `intsetRemove()` is just the reverse of insertion.

### The Set Object

Redis's `setType` object is the user-visible set type that can be manipulated using commands 
`SADD`, `SREM`, `SCARD`, and so on. The set object has two implementations. The first is the `intset` object
that only stores 16-bit, 32-bit, or 64-bit integers. The second is the `dict` object that can store
arbitrary elements as long as they can be hashed and compared.
The initial type of a set object is determined by the first element inserted into the set. If the initial element
can be parsed as an integer, then Redis will initialize the set as an `intset`. However, if later inserted 
elements can no longer be represented as integers, the set is implicitly converted into the `dict` object, hence
allowing the insertion to happen without error.

#### Set Creation

The set object can be created via `SADD` and `SMOVE` if the (destination) key does not yet exist in the current 
database. In this case, the command handler calls `setTypeCreate()` (file `t_set.c`). The function checks whether the
key can be parsed as a long integer using object utility function `isSdsRepresentableAsLongLong()` (file `object.c`),
which itself calls into `string2ll()` (file `util.c`). If true, then the set object is created using 
`createIntsetObject()` (file `object.c`), which initializes an `intset` object and wraps it with `robj` type. 
Otherwise it is created using `createSetObject()` (file `object.c`), which is simply a `dict` object wrapped in 
`robj`. Note that Redis distinguishes these two representations via `robj` object's `encoding` field
(`OBJ_ENCODING_INTSET` and `OBJ_ENCODING_HT`, respectively).
Besides, the `dict` type sets use `setDictType` (global data defined in file `server.c`) for key and values.
The `setDictType` type object defines key comparison, key destructor, and key hash functions while the 
rest are left blank. 

#### Set Operations

The client can check whether an element is a member of the set using the `SISMEMBER` command. Internally, this 
command is implemented by function `setTypeIsMember()` (file `t_set.c`). The function simply multiplexes 
`dictFind()` (file `dict.c`) and `intsetFind()` (file `intset.c`) for `dict` and `intset` types, respectively.
The function returns an integer value to indicate whether the element exists. The integer value is also returned to
the client as the result of the query.

New elements can be added via command `SADD`, `SMOVE`, etc. These commands are implemented with `setTypeAdd()`
(file `t_set.c`). If the set object is a `dict`, it simply calls `dictAddRaw()` (file `dict.c`) to create an entry,
and then sets the key of the entry to the element value.

For `intset` type, however, whenever a new element is added, the function needs to check whether the new element
can be parsed into an integer using `isSdsRepresentableAsLongLong()`. If it is not the case, then the existing
set is converted into a `dict` set by calling `setTypeConvert()`. This function first creates a `dict` type set
using `setTypeCreate()` and then iterates over the `intset` object and converts the integer elements into
`sds` objects using `sdsfromlonglong()` (file `sds.c`). Finally, the converted `sds` type keys are inserted into
the newly created object. Finally, the old `intset` object is freed by calling `zfree()` on the `robj`'s `ptr` field,
and the newly created `dict` object is assigned to the `robj` object.
After conversion is completed, the new key is inserted into the set object by calling `dictAddRaw()`.

One corner case of insertion is when the `intset` object grows to become overly large. In particular, when the
size of the `intset` exceeds `1<<30` (1G entries), the `intset` object is force converted to a `dict` object to avoid 
allocating huge arrays from the system.

Set element is removed using command `SREM`, which is implemented by `setTypeRemove()` (file `t_set.c`).
This function simply multiplexes between `dictDelete()` and `intsetRemove()` for `dict` and `intset`, respectively.
Interestingly, this function also implements a global policy, which states that if the load factor of a `dict`
type hash table (including the set object) drops below a compile-time constant `HASHTABLE_MIN_FILL` (which is 10%), 
then the hash table needs to be shrinked by calling `dictResize()` (file `dict.c`). 
The policy is implemented in function `htNeedsResize()`, which is defined in a seemingly unrelated place: `server.c`.

Lastly, the size of the set, also known as the "cadinality" of the set, can be obtained via command `SCARD`. This
command is implemented by `setTypeSize()` (file `t_set.c`), which multiplexes between `dictSize()` and `intsetLen()`.

### The Listpack Object

Redis implements a `listpack` type to compactly represent lists of integers and strings. 
The `listpack` type is designed to maximize storage efficiency at the cost of lower read performance,
especially random reads. The implementation is in file `listpack.h` and `listpack.c`. 

#### Object Memory Layout

Overall, the `listpack` object is a single block of memory consisting of a header, a body, and an end mark.
The header of the object consists of two fields. The first field is a 32-bit integer storing the total size
of the object including all three parts. The second field is a 16-bit integer storing the number of list 
elements in the body.

The body of the `listpack` object consists of an array of variable-sized entries. Each entry consists of 
a 1-byte `encoding` field describing the encoding of the element (which can be a string or integer, but there are
several forms of storage-efficient encoding for each type). The interpretation of the following bytes depend 
on the `encoding` field. 
In general, if the field indicates that the entry is a form of a string, then the next bytes will be the length
of the string, followed by the string itself. On the other hand, if the field indicates that the entry is a 
form of an integer, then the next bytes will be the integer. 
Finally, there are also special string and integer encodings that "borrow" bits from the `encoding` field. 
In this case, the lower bits of the field will be used to store either the string length or the integer value.

At the end of the listpack object, there is an end mark of value `0xFF`. The end mark can be thought of as a 
special encoding field that does not encode any data, but rather indicates the end of the list. 

#### Entry Encoding

We next discuss the data layout of different encodings. 
If the `encoding` field is of value `2'b0xxx xxxx`, then the entry is a 7-bit integer, and the integer value
is stored in the lower 7 bits of the encoding field. In this case, the entry has no extra bytes as the value
"borrows" 7 bits from the `encoding` field.

Similarly, if the field is of value `2'b10xx xxxx` or `2'b110x xxxx`, then the entry is a 6-bit or 13-bit
integer. In the former case, the lower 6 bits of the field stores the integer value. In the latter case,
the lower 5 bits and the next byte store the integer (and hence it has 5 + 8 = 13 bits).

If the `encoding` field is of value `2'b1110 xxxx`, then the entry is a string with a 12-bit length field.
In this case, the lower 4 bits of the field plus the next byte encodes the length of the string. The string
value is stored compactly right after.
Similarly, if the field is `2'b1111 0000`, then the entry is a string with 32-bit length field. 
No bit is borrowed from the encoding field in this case, and the next 4 bytes encode the length of the string.

The rest three cases for `encoding`, i.e., `2'b1111 0001`, `2'b1111 0010`, `2'b1111 0011`, `2'b1111 0100`,
represent 16-bit, 32-bit, and 64-bit integers, respectively. No bit is borrowed from the `encoding` field, and 
the integer value is stored after the field.

#### Helper Macros and Functions

The source code implementing the `listpack` type provides several helper macros and functions to aid 
programming and promote redability.
Macro `lpGetTotalBytes()` takes a pointer to the header (first byte) of the object and returns the object size
in total number of bytes. Macro `lpGetNumElements()` takes a pointer to the header (first byte) of the object and 
returns the number of elements. Similarly, macros `lpSetTotalBytes()` and `lpSetNumElements()` set the two header
fields given a header pointer and the new value.

Macros whose name begins with `LP_ENCODING_` facilitates encoding-related matters. The order that these macros 
are laid out in the source file is also important, as it is also the order that the `encoding` field should be 
tested due to the special encoding of the field. 

Function `lpCurrentEncodedSizeUnsafe()`, given an entry pointer (pointing to the `encoding` field), returns the 
size of the field including the encoding field and the data. A similar function, `lpCurrentEncodedSizeBytes()`, 
returns the size of the encoding field plus the length field, if the entry stores an integer. Otherwise, it
always returns `1` for integers.

## Redis Python Client Library

At the client side, a client library is needed to communicate with Redis server. The client library implements 
Redis's `RESP` protocol, which encodes strings, arrays, and so on into a specific format that can be understood
by Redis server. Many open-sourced implementations of the Redis client interface are available, and in this section,
we go over the [Python language implementation](https://github.com/redis/redis-py), `redis-py`.

### Initializing the Client Object

The Redis Python interface can be imported into the source using `import redis`. After that, a new `Redis` object 
representing the client can be created by initializing `redis.Redis` with the host name or 
IP address of the Redis server and the port number.
Class `Redis` is defined in file `client.py` of the source tree. In the most general case, the object constructor 
creates a `ConnectionPool` object and saves it to the `connection_pool` field of the `Redis` object.
The `ConnectionPool` object (file `connection.py`) is a thin wrapping layer over the actual connection object, 
`class Connection`. The `ConnectionPool` is responsible for dynamically maintaining a pool of connection objects to
maximize the reuse of allocated OS sockets.
The class provides two main interface methods. The first is `get_connection()`, which either returns an existing
connection object from its `_available_connections` list, or creates a new connection object by calling 
`make_connection()` of itself if the list is empty.
Either way, the new connection is created with the arguments passed into `class Redis`'s constructor,
connected to the Redis server by calling `connect()` on the connection object, and finally 
returned back to the caller.
The second method is `release()`, which returns a connection back to the pool object by inserting it back into
the `_available_connections` list. Note that the pool object will keep connections alive and not disconnect them
proactively from the client's side. 
The pool object is both thread-safe and fork-safe such that connections will not be shared between threads and
processes. The former is guarded by a thread lock such that concurrent usages of the Redis object will not
cause data corruption. The latter is also necessary to avoid different processes after `fork()` to keep sharing 
connections.

Interestingly, the `class Redis` constructor can also be instructed to use Unix domain socket, which is 
an IPC mechanism provided by the OS kernel, when argument `unix_socket_path` is set to anything but `None`. 
Besides, argument `single_connection_client`, if set not `None`, will cause the `class Redis` object to only
open a single connection and save it to field `connection`. In this case, the object is single-thread only.

### The Connection Object

The connection object, which will be initialized and managed by the connection pool, is defined in file `connection.py`
as `class Connection`. The most important interface of this object is `connect()`, which requests a socket from
the OS and connects the to Redis server.
In particular, this function first requests a socket from the OS by calling `_connect()` of itself, which in turn
invokes Python library function `socket()` to access the system call. 
Then it invokes `on_connect()` to authenticate with the server, if the credential is given, set the
client's name, and then select the database. All the operations in this function are optional, and will
only be performed when the information is given to the `class Redis` object (via the constructor) owning the 
connection object.

The default connection object assumes TCP/IP protocol without TLS. Alternatively, users can instruct the `Redis`
object to use Unix domain sockets, which is a form of IPC that binds to a local file system node rather than
to a host name of IP address. The domain socket connection object is implemented as `class UnixDomainSocketConnection`
(file `connection.py`), which inherits from the connection class discussed above.
The domain socket class overrides the `_connect()` method such that it creates a domain socket object 
by calling Python library function `socket()` with the socket type being `AF_UNIX`.

The connection type is selected by passing different class objects into `class ConnectionPool`'s contructor as the
`connection_class` argument. 

### Executing Commands

After constructing the object and setting up the connection, the `class Redis` object is returned to the caller,
which is ready to accept commands.
Commonly used commands such as `GET` and `SET` are implemented in `class BasicKeyCommands` (file `commands/core.py`).
For example, the `GET` command is implemented as a simple function `get()`, which does nothing else except  
calling `execute_command()` with the command string `GET` as the first argument and the key as the second argument.

`class BasicKeyCommands`, together with a few other classes implementing commands, are inherited by the main `Redis`
class. Therefore, calls to method `execute_command()` within the `get()` (which is called by the user using the 
`Redis` object as `self` pointer) will eventually land in `class Redis`'s `execute_command()` method.
Function `execute_command()` (file `client.py`) accepts unnamed arguments in `args` and keyword arguments 
in `options`. This function first grabs a connection object either from its `connection` field (in the case
of single connection `Redis` object), or by calling `get_connection()` of the pool object.
Then it indirectly invokes `_send_command_parse_response()` to send the command and wait for the response.
Function `_send_command_parse_response()` (file `client.py`) simply calls `send_command()` on the connection
object, and then waits for and parses the response by calling `parse_response()`. The 
value from `parse_response()` is returned to the user.

### Generating the RESP Request Stream

Function `send_command()` (file `connection.py`) generates the request stream by calling method `pack()` on 
its `_command_packer` field. The field is of type `class PythonRespSerializer` and is assigned during 
`class Connection` object's construction by calling method `_construct_command_packer()` (file `connection.py`). 

The request stream of a command is generated by calling `pack()` on the `class PythonRespSerializer` object.
The pack method takes a list argument `args` and implements Redis's RESP protocol. 
The RESP protocol serializes strings, integers, lists, and so on, into a single stream that can be understood
by the Redis server. For Redis requests, the REST-compatible stream begins with a `*` symbol, followed by
the number of arguments (including the command itself) and then `\r\n`. 
The command is encoded as a string object, which begins with `$`, followed by the length of the string,
then followed by `\r\n`, and finally followed by the string itself (which can contain `\r`, `\n`, or both).
The rest of the stream consists of the arguments in their corresponding RESP encoding. In the simplest
scenario, there is no argument, and the stream only contains the command. In common scenarios such as 
`GET`, there is only one argument, which is the key, and the key is encoded by RESP as a string object.

Method `pack()` generates the request stream in the exact same way as described above. It first computes the 
size of the argument list, and generates the header of the stream by joining `SYM_STAR`, the length of the string,
and `SYM_CRLF` together.
Then, for every element in the argument list (including the command, which is the first element of the list),
it generates a string object by joining `SYM_DOLLAR`, the length of the element, `SYM_CRLF`, the object content,
and finally another `SYM_CRLF`.
The final result can be in one or more buffer objects to avoid large data copy. The buffer objects are 
inserted into a list and returned to the caller.

### Sending The Stream

The returned list of buffer objects from `pack()` is then given to the `send_packed_command()` method as the
first argument. Function `send_packed_command()` iterates over the list, and for each buffer object, invokes 
`sendall()` on the socket object of the connection to send it to the Redis server.

### Waiting for the Result

After the command is sent, the control flow returns to function `_send_command_parse_response()` (file `client.py`),
and will then call `parse_response()` of the `Redis` object to wait for the result. 
Function `parse_response()` (file `client.py`) takes the connection object as its first argument and it
further calls into the `read_response()` method of the connection object.
Function `read_response()` (file `connection.py`) wraps over `read_response()` on the same `_parser` field.
The `_parser` field is assigned during construction of the connection object (by calling `set_parser()` on `self`) 
and is of type `class PythonParser`.

Function `read_response()` (file `connection.py`) of `class PythonParser` calls `_read_response()` of the same object.
The latter in turn calls `readline()` on its `_buffer` field. The `_buffer` field is assigned when the connection
is initialized, in the connection object's `on_connect()` method (which calls the `on_connect()` method of the
parser). The type of the `_buffer` field is `class SocketBuffer`. Its `readline()` method (file `connection.py`)
calls `_read_from_socket()` in a loop, which in turn invokes `recv` on the connection socket's, receiving 
response data and appending it into the parser's internal buffer object `_buffer`.
Function `readline()` returns on seeing a trailing `SYM_CRLF` in the response stream.

After the response message is fully received, the control flow returns to the parer object's `_read_response()` method.
This method then inspects the first character of the response message and parses the rest based on the first character. 
If the first character indicates that more data should be received, the method will further call `read()` method
of the `_buffer` to complete the receival process. The response message is returned to the caller after it is 
fully received. The response message will then climb up the call chain through the 
connect object's `_read_response()` and `read_response()`, the `Redis` object's `parse_response()`, 
`_send_command_parse_response()`, and `execute_command()`, the `BasicKeyCommands` object's `get()`, 
and finally be returned to the user.

## Build, Compilation, and Usage

### Connecting to Redis Server using Telnet

Instead of using a client that implements RESP, users can interact with Redis server using `telnet`
by manually typing the command. For a Redis server instance started on the local host on the default port `6379`,
users can connect to it using the following telnet command:

```
telnet localhost 6379
```

After connecting to the server (there is no prompt), users can then send commands with space-separated arguments.
For example, in order to set a key `key1` to string `value1`, type the following command:

```
set key1 value1
```


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
