---
layout: post
title:  "QEMU Cheat Sheet for Full-System Simulation"
date:   2022-03-08 22:12:00 -0500
categories: article
ontop: true
---

### Data Disk Related Topics

**Creating, Mounting, and Formatting New Image File**

Usually, you need to create a new image file and copy data to it such that the workload files and the dataset,
which can be quite large in certain cases, will not consume storage on the base image (which is often pretty limited).
New images can be created by running the following command:

```
qemu-img create -f qcow2 [path] [size]
```

where `[path]` is the path to the new image you want to create, and `[size]` is the maximum size of the image.
Note that the unit of `[size]` can be specified using `m`/`M`, `g`/`G`, etc.

After image creation, a file system needs to be created on it in order to be used as an extra data disk.
In order to create a file system, the image must be added as a virtual device first. This can be done
with the following command:

```
sudo qemu-nbd --connect=/dev/nbd0 [path]
```

where `[path]` is the path to the image file you just created, and `/dev/nbd0` is the virtual device name. 
If this command reports error "qemu-nbd: Failed to open /dev/nbd0: No such file or directory", then run the 
following first, and then retry:

```
modprobe nbd max_part=8
```

The image is then formatted with a file system using the conventional Linux command as follows:

```
sudo mkfs.ext4 /dev/nbd0
```

This command will create a new ext4 file system, which is probably the most common type for a data disk. You can also
choose other types of formatting program based on the particular needs.

**Populating the New Image File**

After the file system is created, the image can be mounted to the host file system as a regular device (assuming
it has already been virtualized as `/dev/nbd0`):

```
sudo mount /dev/nbd0 [path]
```

where `[path]` is the path of the mounting point. After the mounting operation succeeds, the image can be written
into just like a regular disk. The image also needs to be unmounted after usage with the following command:

```
sudo umount /dev/nbd0
```

Optionally, the virtual device can also be disconnected with the following command:

```
sudo qemu-nbd --disconnect /dev/nbd0
```

If the mounted directory can only be written by root user (e.g., prompted permission denied when trying to copying 
or creating files), you need to run the following command to change thw ownership
back to the current user:

```
chown -R [user name] [mount path]
```

**Emulating the Image File as a Disk**

The newly created image file can be emulated by QEMU as an extra device by configuring a secondary hard disk
when starting QEMU:

```
qemu-system-x86_64 -m 512m -hda [System disk image path] -hdb [Data disk image path]
```

After the system has started, the image disk can be mounted just like a regular device 
(within the emulated system):

```
sudo mount /dev/sdb [path]
```

where `[path]` is the mounting point within the emulated system.

**Converting Image from qcow3 to qcow2**

If QEMU reports error saying `'ide0-hd1' uses a qcow2 feature which is not supported by 
this qemu version: QCOW version 3` (note that `ide0-hd1` can be different based on your
startup configuration), then the image is created with a different version of qcow, and
needs to be downgraded. The downgrade command is as follows:

```
qemu-img amend -f qcow2 -o compat=0.10 [path]
```

where `[path]` is the path to the image file to be downgraded. The downgrade will happen on the same
file as the input, and therefore, no output file is specified.

### System Disk Related Topics

**Downloading the System Image**

System images are readily available at Ubuntu official site:

```
https://cloud-images.ubuntu.com/
```

The proper image for QEMU emulation is the one with `amd64` in the file name (for x86-64 emulation, of course), 
and `.img` as suffix. Typically, emulation should use the non-KVM version, as the KVM version contains a slightly
different Linux kernel that is optimized towards hardware virtualization. 

**Setting the Root Password**

By default, the system image will only have one user, `root`, and the password is not configured yet. That means
you cannot login directly into the system with a fresh new image. To configure the password of root user, use
the following command:

```
virt-customize -a [path] --root-password password:[password]
```

where `[path]` is the path to the system image, and `[password]` is the password to be used. After this, the 
system can be logged in using `root` and the user name, and whatever password you just set as password.

**Installing Packages**

With a system image, new packages can be installed without booting into the system and connecting it to the 
network. This requires `virt-customize` utility, with the command as follows:

```
virt-customize -a [path] --install [package name]
```

where `[path]` is the path to the system image, and `[package name]` is the name of the package as you would have
used with `apt-get install`.

### Building and Emulating Linux Kernel

**Compiling Linux Kernel**

The first step of compiling a customized Linux kernel is to download the kernel source tree from the official kernel 
repository: `https://www.kernel.org/`. It is best practice to pick the kernel noted as `mainline` or `longterm` for
stability and compatibility.

After downloading the kernel, which is a `.tar.gz` file, unpack the kernel source tree using the command:

```
tar -xvzf [Path to the compressed tarball]
```

Before invoking `make`, you need to first specify a kernel configuration file. Two of the most commonly used 
configurations are `make defconfig` and `make oldconfig`. The former uses the default configuration that comes with
the kernel source tree, which should work in most cases. The latter uses the configuration of the system on which
`make` is invoked. In particular, it extracts the current kernel build configuration from the current system's 
`/boot/` directory. Customized configurations can also be generated either manually or using an existing configuration
file as a baseline, but we do not discuss them here.

After invoking the command, the kernel build configuration will be written into a file `.config` under the source tree.
This file will be used by the build system. Just run `make` to start building the kernel. You may also want to specify
`-j` followed by the number of concurrent build threads. Refrain from using `make -j` with a large thread count or
without any number which will use the parallelism of the system, though, especially on large machines with 
tens of cores. The reason is that the kernel 
building process is cpu- and memory-intensive, and dedicating all cores for the task may deplete system memory and 
render the entire system irresponsive.

If something goes wrong, or you want a clean build, then execute the following make command to revert the
kernel source tree to the initial state:

```
make mrproper
```

This command will remove all intermediate files as well as the generated configuration file.

**Booting QEMU with the New Kernel**

Once kernel build finishes, you should be able to find the uncompressed kernel image, `vmlinux`, in the root of 
the kernel source tree. This image, however, cannot be directly used to boot the system. 
The compressed kernel image resides in `arch/x86/boot/` as file `bzImage`.

One way of replacing the old kernel with the newly compiled one is to copy the binary `bzImage` into the 
`/boot/` directory of the disk image (not your host system!) as `vmlinuz`. The bootloader will use it as 
the kernel the next time you start the system. 

An even better way, if you are using QEMU, is to specify the kernel image to load using QEMU command line 
option `-kernel`. This option allows users to specify a kernel image (i.e., the `bzImage`) that exists in the 
host system (not the emulated guest!), such the image will be loaded directly by QEMU into the emulated address 
space, rather than following the regular booting process and using whatever in the emulated `/boot/` directory.

In addition to the `-kernel` option, you need also to specify the following to QEMU in order to properly boot 
the system:

```
... (Other options)
-kernel [Compressed kernel image path] \
-append "root=/dev/sda1 console=ttyS0 nokaslr" \
... (Other options)
```

The `-append` switch sets the kernel boot options, which will be read by the kernel during the boot. 
`root` specifies the device that will be mounted as the root file system (i.e., the `/` directory). In this 
example, we use `/dev/sda1`, assuming that the system disk drive (i.e., the Ubuntu image) is specified 
as `-hda [System disk image path]`.
`console=ttyS0` just ensures that the output can be seen on the host terminal. If this option is missing, nothing 
will show up after you start the emulation.
`nokaslr` is not strictly required, but as it disables kernel address space randomization, you would expect it to
introduce less performance noise compared with the case where randomization is enabled.

I also present the complete list of command line arguments that I use below (under the root of QEMU source tree):

```
./build/qemu-system-x86_64 \
-smp 1 -m 512 \
-nographic \
-hda [System disk image directory]/ubuntu-20.04-server-cloudimg-amd64.img \
-hdb [Data disk image path] \
-kernel [Compressed kernel image path] \
-append "root=/dev/sda1 console=ttyS0 nokaslr"
```

The `-m` option specifies the amount of physical memory allocated to the emulated guest. `-smp` specifies the number
of emulated CPUs. `-nographic` disables QEMU's graphic window, and will redirect input/output to/from the emulated
guest to the current terminal on the host.

**Virtualizing Time Properly**

By default, QEMU does not virtualize time, meaning that the emulated guest system is able to observe the
time elapsed on the host system, rather than in the emulated environment. The reason of not virtualizing time is 
that QEMU only performs functional emulation, without the capability of deriving the timing of instructions and 
I/O operations. One consequence of lacking time virtualization is that the emulated guest system may behave 
differently under QEMU, since certain kernel or user components may require precise timing. One example is 
kernel RCU, which is monitored by a background kernel thread. The following kernel message might be printed
on the console, if the emulated system is running at extremely low throughput (e.g., you added lots of 
instrumentations which slow down the emulation significantly):

```
[  854.090892] rcu: INFO: rcu_preempt self-detected stall on CPU
[  854.143514] rcu: 	0-...!: (2683 ticks this GP) idle=59b/1/0x4000000000000000 softirq=79396/79396 fqs=1 
[  854.276564] rcu: rcu_preempt kthread timer wakeup didn't happen for 60043 jiffies! g143537 f0x0 RCU_GP_WAIT_FQS(5) ->state=0x402
[  854.382524] rcu: 	Possible timer handling issue on cpu=0 timer-softirq=27154
[  854.445642] rcu: rcu_preempt kthread starved for 60046 jiffies! g143537 f0x0 RCU_GP_WAIT_FQS(5) ->state=0x402 ->cpu=0
[  854.549432] rcu: 	Unless rcu_preempt kthread gets sufficient CPU time, OOM is now expected behavior.
[  854.611767] rcu: RCU grace-period kthread stack dump:
[  855.205647] rcu: Stack dump where RCU GP kthread last ran:
```

This happens, because the emulated system runs much slowly than it is supposed to be, but the kernel is able to
observe wall-clock time, thus reaching to the wrong conclusion that the system has been stalled.

To address this matter, ~~run QEMU with the option `-icount shift=auto`~~, run QEMU with the option `-icount shift=1`, which instructs QEMU to virtualize time based on how many
instructions it has executed. With `icount` enabled, the emulated guest system will stop printing the RCU warning
message from the kernel thread, since the kernel can now only observe elapsed time as the number of instructions
that have been executed.

**Beware of SIMD Instructions**

If you run into illegal instruction fault on the emulated guest system, but the same binary works fine on 
your host system, one of the many possible causes is that QEMU does not support the full set of SIMD instructions,
especially when the binary is cross-compiled on the host system rather than the guest.
Once identified, the issue is relatively easy to resolve -- Just disable SIMD instructions in the compiler option.
On `gcc`, this can be done by removing options like `-mavx`, `-mavx2`, etc.

**Disabling Ubuntu Automatic Upgrade**

If you are using an Ubuntu distribution, it is likely that automatic upgrade is enabled by default, which will
attempt to check and download upgrades in the background. To disable the automatic update service, which is almost
always what you want to do (because it consume system resources, and because it introduces lots of noises),
run the following command:

```
sudo apt -y purge unattended-upgrades
```

I particularly uninstalled this component because I observed high CPU occupation by a process of the same name.
You may or may not need to do the same, depending on your system configuration.

To completely disable all updates, check out the files under the directory `/etc/apt/apt.conf.d/`. Certain files
contain switches that configure automatic update. 
In my case (`Ubuntu 20.04 LTS`), it is a file named `10periodic`, and I disabled the switch 
`APT::Periodic::Update-Package-Lists` by changing its value to `"0"`. Some online resources also indicate
that you should look into the file `20auto-upgrades` under the same directory. In my case, I did not see that
file, and the options are actually in `10periodic`.

Please note that what I described in this section only applies to an emulated system, where security is not 
a concern, and that we want to minimize performance noise introduced by unrelated applications as much as possible.
On an Ubuntu distribution for daily usage, it is strongly recommended that you should enable automatic update,
and periodically install these updates to keep the system secure.

**Configuring the Emulated Terminal**

Since we used the option `-nographic` to start QEMU, all outputs from the emulated system will be redirected to
the host's terminal where QEMU is started. 
One problem is that the size of the host terminal (which can be set by adjusting the window size on the host) may not
match the size in the emulated guest, which can give you weird artifacts. If you observe these artifacts, one way of
solving it is to configure the guest terminal rows and columns to match those of the host, using the command below:

```
stty rows [Number of rows] cols [Number of columns]
```

The two parameters given to the `stty` command must exactly match the host terminal size. One way of obtaining such 
information in Ubuntu is to move your mouse to one of the four corners of the window, and then hold the mouse left 
button when the cursor turns into an arrow. The size of the terminal should be shown at the middle of the window
(in col * row format, rather than the opposite).

**QEMU Monitor**

QEMU provides a "monitor" that allows host system users to control the emulated guest system. 
To wake up the console, press "Ctrl+A" on the host system with the focus on the emulated terminal 
(assuming you are on MacOS or Ubuntu), and then press "c". QEMU console prompt `(qemu)` should then be printed.
You can then experiment with the monitor by typing commands into it. 
A good beginning point is to type `help` to view a complete list of supported commands and their actions.

If you just want to terminate QEMU immediately, a shortcut is provided as "Ctrl+A" and then pressing "x".

Please note that QEMU monitor seems to run asynchronously with the emulated system, at least it is the case 
from my experience.
The emulated system will keep running and printing on the terminal even with the monitor being active.

### System Snapshots

**Saving System Snapshots**

QEMU has a handy feature that saves and loads full-system snapshots of the emulated system. The full-system snapshot
consists of the memory, CPU, and disk states, such that execution can resume, at a later point, right on 
the moment where the snapshot is taken.

To use this feature, you need to first boot the system in the normal manner, and then enter QEMU monitor.
A new snapshot can be created by typing the following command into the console:

```
savevm [Snapshot Tag]
```

where `[Snapshot Tag]` is an arbitrary name you chose for it. The snapshot is generated and attached to the system
disk image file (i.e., the one you specify with `-hda` option). Multiple snapshots can be created on the same 
system disk image, as long as each of them is given a unique name.

The list of snapshots can be seen with `qemu-img` utility without invoking QEMU, using the following command:

```
qemu-img snapshot -l [System disk image path]
```

If multiple images are loaded on the emulated system, then the snapshot tag will exist on all image files. 

Snapshots can be deleted using the same utility by passing `snapshot -d` with the name of the snapshot.
Alternatively, they can also be deleted using `delvm` while in the QEMU monitor.

**Loading System Snapshots**

System snapshots can be loaded in two ways. In the less common approach, you can enter QEMU monitor, and then
type `loadvm [Name]` where `[Name]` is the name of the snapshot to be loaded. 
Snapshots can also be loaded using `-loadvm` option followed by the name of the snapshot. 
In both cases, the rest of the command lines for starting QEMU must match those where the snapshot was taken. 

Note that by loading a system snapshot, modifications to the disk image after the snapshot was taken will be
rolled back.

**Memory Snapshots**

The above mechanism of creating and loading full-system snapshots (called "internal snapshot" in QEMU's official
documentation) is handy for debugging and development, but it has one fatal flaw: you cannot share the image between
multiple instances of emulated guests. The reason is that QEMU will lock the image file in exclusive mode, which
prevents another process from acquiring the same write lock.

One trivial solution is to make multiple copies of the disk files, with each being used by their own instance.
This approach, however, is storage-inefficient, because the image can be quite large, and besides, most parts 
of the images will be identical anyway. 

To deal with this, we leverage QEMU's live migration and snapshotting mechanism to support sharing image files
between multiple instances. Live migration is a technique that serializes the emulated system states, including
memory states and device states (not including the disk image, though) to an external stream (most likely a file,
but sockets and other types of streams also work). The emulated system states can be loaded back later
to resume execution just like internal snapshots (actually, internal snapshots are implemented with this feature,
with the only addition being that the object storing system states is appended to the disk image).
Snapshotting is an emulation mode of QEMU, in which all modifications to the disk images are redirected to a 
temporary file, and discarded on exit. Under snapshotting mode, disk images will be opened in read mode, rather
than write-exclusive mode, because QEMU is guaranteed to not update them.

To perform live migration, enter QEMU monitor using the key combination Ctrl+A C, and then enter the following 
command:

```
migrate "exec: cat > mem_snapshot"
```

This command will capture the current system state, and save it to an external disk file named `mem_snapshot`. In order
to load the saved states on the next startup, use the `-incoming` option in QEMU's command line:

```
-incoming "exec: cat mem_snapshot"
```

which restores the system state and resumes execution at the point where live migration is performed.

On the other hand, in order to enable snapshotting mode, just add the following option to QEMU:

```
-snapshot
```

All modifications to the disk image will be discarded after the program exits, and the overall system state will
remain the same on future invocations. Most importantly, multiple instances can be started on the same image files
under snapshotting mode, allowing these files to be shared under copy-on-write.

### QEMU Plugins

**Using Plugins to Access QEMU Internal States**

QEMU plugins are implemented as shared objects that expose certain interfaces in order for 
QEMU to load and unload. These plugins interact with QEMU and access QEMU's internal states via 
plugin-specific function calls that expose the states of translation blocks, instructions, memory operations, etc.
We do not discuss QEMU plugin development and plugin API here. Interested readers are encouraged to
find online resources that cover these topics, such as 
[the official documentation](https://qemu.readthedocs.io/en/latest/devel/tcg-plugins.html).

**Loading Plugins**

QEMU plugins are compiled independently from the source tree (but may include header files from the source). 
Once the `.so` file is generated, it can be loaded by QEMU at startup time by specifying `-plugin` option
in the command line as follows:

```
-plugin [Path to plugin .so file]
```

If custom arguments are to be passed to the plugin itself, these arguments should follow the path to the 
`.so` file, after a comma, which is shown as follows:

```
-plugin [Path to plugin .so file],arg=[1st argument],arg=[2nd argument],arg=[3rd argument],...
```

QEMU does not attempt to parse whatever that follows `arg=` after each comma, and every character between the 
equal sign and the next comma (or the next space character) will be passed to the plugin as-is.

**Accessing Plugin Arguments**

Arguments provided to the plugin can be accessed in the plugin entry point function, `qemu_plugin_install()`.
This function will be called first after the `.so` file is loaded into QEMU's address space by the dynamic linker. 
The function is called with `argc`, which indicates the number of arguments, and `argv`, which is a vector of 
`char *` that stores the contents of the arguments.
Note that the value of `argc` matches the number of custom arguments specified in the command line, instead of
being one plus the number, unlike the `argc` value in C language runtime. 

Note that the way arguments should be passed differs from what was described in 
[the official documents](https://qemu.readthedocs.io/en/latest/devel/tcg-plugins.html). More specifically, the 
official documentation claims that arguments can be passed by appending the key-value pairs of the 
form `,key1=value1,key2=value2`, after the `.so` file path. In practice, this will only incur an error
saying something like `-plugin: unexpected parameter 'key1'; ignored`. 

The part of QEMU that handles plugin arguments is in `plugins/loader.c`, function `plugin_add()`. As can
be seen clearly from the source code, the function only recognizes two switches, namely, `file` and `arg`.
The contents that follows `file` will be treated as the path to the `.so` file, and the contents that follows
`arg` will be added to the custom argument list (`p->argc` and `p->argv`), and later on passed to the plugin
entry point function in function `plugin_load()` by calling the function pointer `install`. 
The `install` pointer stores the address of the plugin's entry point, which is resolved from the plugin object 
that was just loaded.

**Redirecting QEMU's Input**

When `-nogaphic` option is used, QEMU accepts inputs from the host terminal, and emulates a character device 
that forwards terminal input to the emulated guest OS. 
This way of interaction, however, requires manual input to the host terminal, which is not easily automated.
More than often, we wish to be able to send commands from another program to QEMU, such that the entire 
process can be automated without human intervention.

One way of redirecting QEMU's input from the host terminal to another channel is to use a combination of 
`dup2()` system call and named pipe IPC.
The `dup2()` system call redirects a file descriptor to another opened file structure. All other system calls
that use the redirected file descriptor will then operate on the latter, instead of the former.
Named pipe IPC is an inter-process communication mechanism that replies on Linux's file abstraction for
passing information from one process to another. In named pipe IPC, a file system entity is created, which 
can be opened, read from and written to like a normal file. The writing process (the sending end) 
calls the `write()` system call on the file descriptor after opening the named pipe as a regular file 
with `O_WRONLY` permission, and the reading process (the receiving end) calls `read()` on the file descriptor
after opening the same file with `O_RDONLY` permission. 
In order for QEMU to read input from the named pipe rather than from `stdin`, we use `dup2()` to redirect
the `stdin` file descriptor number (`STDIN_FILENO` in libc headers) to the descriptor of the named pipe.

The perfect place to implement this is in QEMU plugin's initialization routine, `qemu_plugin_install()`.
As noted earlier, this function also receives the plugin's arguments, which can carry the file 
name of the named pipe.
The named pipe is created by calling `mkfifo()`, with the first argument being the file name of the named pipe, and 
the second argument being the permission (usually just set it to `0666`).
After the named pipe is created, the plugin can then connect it by calling `open()`, with the permission being 
`O_RDONLY`. The operation system will block the call with `O_RDONLY` permission until a writer has connected,
so no extra synchronization is required here.
The writer process, on the other hand, just connects to the named pipe by calling `open()` with the permission being 
`O_WRONLY`. Once the writer process has connected, both processes will proceed.

On the QEMU side, the next step is to redirect stdin to the named pipe. 
We first call `dup()` on `STDIN_FILENO` to create a backup file descriptor that refers to the original `stdin` 
file structure, such that we can restore `stdin` as the input channel as needed.
The backup descriptor is stored elsewhere for later restoration.
Then we call `dup2()` with `oldfd` being the named pipe's file descriptor, and `newfd` being `STDIN_FILENO`.
After this call returns, all QEMU's input will be read from the named pipe, rather than from the host terminal. 

On the sending side (which is likely the simulation backend), shell commands can just be written to the file
descriptor, which will be received by QEMU as external inputs, sent to the OS, and then interpreted by the 
emulated shell. Binary data can also be sent, but they may incur peculiar behavior, so users should be careful when
sending binary data.

Note that the writer process should keep connected to the named pipe and never close the file descriptor or
exit, before the simulation terminates. This is because once the writer process closes the file descriptor, 
it can never reconnect again. Meantime, on the reader side, `read()` will always return `0` without blocking,
which is the behavior when End-of-File (`EOF`) is met.

**Sending Special Command via Named Pipe**

One of QEMU's features, the QEMU monitor, requires users to press `Ctrl+A` on the host terminal to activate. 
When the input is sent via the named pipe, it is not straightforward to emulate this keyboard press, because 
there is no ASCII code that corresponds to the `Ctrl` key.

Further inspection to the control sequence, however, would reveal that the terminal will translate `Ctrl+A`
key combination to ASCII code `0x01`, and put it into the `stdin` stream.
Therefore, in order to enter QEMU monitor when named pipe IPC is in effect, the writer just need to write 
`0x01` and `c` into the pipe. 
Similarly, in order to terminate emulation, just write `0x01` and `x`, which is identical to pressing `Ctrl+A`
followed by the `X` key.

The part of logic that handles this in QEMU resides in file `chardev/charmux.c`, function `mux_proc_byte()`. This 
function is called by its preceding function, `mux_chr_read()`, with every character received from the input 
stream. The function simply checks whether the current character is `term_escape_char`, which is defined as a 
global variable `0x01`, and if true, then it flips the local variable `term_got_escape` to `1`, and for the 
next character received, the big switch statement will be used to interpret them differently.
As we can see in the `case 'x'` branch, when `0x01` followed by `x` is received, QEMU will simply just flush the 
output (which is emulated to print on the host terminal), and then exit by calling `exit()`.
Correspondingly, when `0x01` followed by `c` is received, QEMU will switch to another device
context by calling `mux_set_focus()` (and this is exactly why the device is called `charmux` -- it multiplexes between
several registered device contexts).

**Switching Back and Forth Between Named Pipe and Stdin**

Having QEMU's input disconnected from `stdin` and redirected to a named pipe has a side effect: You cannot 
directly interact with QEMU on the console where you started it. In order to maintain flexibility, we would 
prefer to have both ways of interaction available, with some ways of switching between these two.

To this end, I added a new QEMU monitor shortcut, `Ctrl+A Z`, to switch between the two modes of interaction.
The new monitor shortcut is added to function `mux_proc_byte()` in file `chardev/charmux.c`. Essentially, we add
a new `case x` branch to the big `switch` statement that handles escaped sequences. 
Within that branch, we just check whether the current input is from `stdin` or from the named pipe, and then use 
`dup2()` to redirect input to the other one. 

**Dynamically Adding Features**

One of the nicest things about QEMU plugins is that they are simply dynamically loadable shared object files, 
indicating that we can also import functions from the plugins to enrich QEMU features.
By default, QEMU expects the plugin to export two symbols. The first is `qemu_plugin_install()`, which is the 
plugin's initialization routine that will be called when it is loaded. 
The second is `qemu_plugin_version`, which is an integer typed global variable that declares the expected API
version from QEMU. QEMU plugin loader will check this version to ensure that a compatible API is implemented.
As of the time of writing, QEMU supports API version 1, which is defined as a macro `QEMU_PLUGIN_VERSION`, 
in file `include/qemu/qemu-plugin.h`

Additional symbols can be exported from a plugin and imported by QEMU at run time. These symbols should 
be defined as non-static global names with declarator macro `QEMU_PLUGIN_EXPORT`, which just translates
to linker directive `__attribute__((visibility("default")))` on Linux.
Then, in file `plugins/loader.c`, function `plugin_load()`, the pointer to the aforementioned function can be
obtained by calling `g_module_symbol()`. We do not elaborate on how the function should be used, as there
are abundant number of examples in that file. 
After obtaining the function pointer, it can be called by other QEMU components as a regular function until
the plugin is uninstalled.

### Deploying Workloads

**Running Jobs Asynchronously**

Linux bash shell provides a convenient way of starting asynchronous jobs: Just adding an ampersand (`&`) symbol
after the shell command, and shell will spawn a new process to execute the command in the background, 
and return immediately for the next command, without waiting for it to complete first. 
The background process still has its stdout connected to the current terminal, but the `stdin` is disconnected,
meaning that the process can normally print, but when it attempts to read from `stdin`, the process will block.
Standard input can also be reconnected back to a potentially different terminal with bash's job control utility,
but it seems to be less used for our purpose, and therefore we do not cover it here. 

**Redirecting Standard Output and Error**

Running multiple background jobs concurrently on the same terminal, however, will mess up the output which makes it
hard to comprehend. It is good practice to redirect standard output and error of background processes to the 
corresponding external files, such that the output of the jobs can be viewed individually.
The bash syntax for doing this is as follows:

```
[Your command] > [Output file name] 2>&1 &
```

in which the `>` operator simply redirects the `stdout` of the process (whose file descriptor number is 1) 
to the given file, and the following `2>&1` redirects `stderr` (whose file descriptor number is 2) to stdout,
which has already been redirected to the file. Note that the order of `>` and `2>&1` is important, because 
otherwise, the `stderr` will be redirected to the regular `stdout`, and only after that `stdout` will be 
redirected to the file.

If you want not only to redirect the standard output and error to a file, but also to see them on the terminal,
you can use the `tee` utility as follows:

```
[Your command] > 2>&1 | tee [Output file name]
```

which will first redirect the program's `stderr` to `stdout`, and then redirect both to the input of the 
`tee` utility. The `tee` utility, given an output file name, will print whatever it has received in the input
on the terminal, in addition to writing them into the file.

**Preserving Jobs Across Sessions**

One problem with running jobs in `ssh` sessions is that the jobs might be killed after you have logged out (Note:
this behavior is not consistent; See below for more details).
This is because a hung up signal `SIGHUP` might be sent by the `sshd` process to the login shell spawned by
it. The login shell may then forward this signal to all the child processes that itself had spawned as jobs, 
resulting in the termination of those child processes as well. 

To avoid such behavior, the best practice is to start a separate shell that is independent from the login
shell, which can survive different sessions (i.e., logins and logouts). The `screen` utility supports exactly
this feature. To start a new shell, simply run `screen` on the login shell, after which a new shell will be
started, replacing the previous one on the terminal. 
You can invoke background jobs as usual in the new shell, and eventually detach from the shell
by pressing `Ctrl+A` followed by `d`.
The shell can be reattached to (potentially after logouts and logins) by running `screen -r`.
Processes started in the `screen` shell are safe from session to session, as the `screen` utility is programmed
to be unaffected by `SIGHUP` signals.

As mentioned earlier, however, the killing behavior of ssh sessions are inconsistent on different machines
due to different configurations.
Sometimes background jobs will not be sent the `SIGHUP` signal if the ssh session is terminated peacefully
by typing `logout`, `exit` or pressing `Ctrl+D`, and hence the background processes can keep running in these 
cases. You can verify whether it is the case by running `sleep 1000000 &`, logout of the session, log back in,
and use `ps x` to see if the `sleep` process is still there.
The behavior may again be different, if the session is terminated by long-time inactivity or network
disruption, in which case `SIGHUP` will be sent.
To prevent surprises, it is therefore recommended to always use the `screen` utility. 
