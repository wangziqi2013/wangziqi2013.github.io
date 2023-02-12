---
layout: post
title:  "Notes on Redis Source Code Reading"
date:   2023-02-11 22:14:00 -0500
categories: article
ontop: true
---

### Workflow from Input to Command Handler

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

### The Dict Object

Dictionary objects lie at the central of Redis as the database itself is implemented as a `struct dict` object.
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

The first `--save` options with an empty string disables RDB snapshotting. The second `--appendonly` option disables
AOF.