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
sudo makefs.ext4 /dev/nbd0
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

**Emulating the Image File as a Disk**

The newly created image file can be emulated by QEMU as an extra device by configuring a secondary hard disk
when starting QEMU:

```
qemu-system-x86_64 -m 4g -hda [path to system image] -hdb [path to data image]
```

After the system has started, the image disk can be mounted just like a regular device 
(within the emulated system):

```
sudo mount /dev/sdb [path]
```

where `[path]` is the mounting point within the emulated system.

**Converting Image from qcow3 to qcow2**

If QEMU reports error saying "'ide0-hd1' uses a qcow2 feature which is not supported by 
this qemu version: QCOW version 3" (note that ide0-hd1 can be different based on your
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
virt-customize -a [path] --set-password password:[password]
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

### Building and Running Linux

**Compiling Linux Kernel**

The first step of compiling a customized Linux kernel is to download the kernel source tree from the official kernel 
repository: `https://www.kernel.org/`. It is best practice to pick the kernel noted as `mainline` or `longterm` for
stability and compatibility.

After downloading the kernel, which is a `.tar.gz` file, unpack the kernel source tree using the command:

```
tag -xvzf [file name of the compressed tarball]
```

Before invoking `Make`, you need to first specify a kernel configuration file. Two of the most commonly used 
configurations are `make defconfig` and `make oldconfig`. The former uses the default configuration that comes with
the kernel source tree, which should work in most cases. The latter uses the configuration of the system on which
`make` is invoked. In particular, it extracts the current kernel build configuration from the current system's 
`/boot/` directory. Customized configurations can also be generated either manually or using an existing configuration
file as a baseline, but we do not discuss them here.

After invoking the command, the kernel build configuration will be written into a file `.config` under the source tree.
This file will be used by the build system. Just run `make` to start building the kernel. You may also want to specify
`-j` followed by the number of concurrent build threads. Refrain from using `make -j` with a large thread count or
with the parallelism of the system, especially on large machines with tens of cores, because the kernel building 
process is memory-consuming, and using up all cores for the task may deplete system memory and render the entire 
system irresponsive.

****

**Disabling Ubuntu Automatic Upgrade**

If you are using an Ubuntu distribution, it is likely that automatic upgrade is enabled by default, which will
attempt to check and download upgrades in the background. To disable the automatic update service, which is almost
always what you want to do (because it consume system resources, and because it introduces lots of noises),
run the following command:

```
sudo apt -y purge unattended-upgrades
```

I particularly uninstalled this component because I observed huge CPU occupation of a process of the same name.
You may or may not need to do the same, depending on your system configuration.

To completely disable all updates, check out the files under the directory `/etc/apt/apt.conf.d/`. Certain files
contain switches that configure automatic update. 
In my case (`Ubuntu 20.04 LTS`), it is a file named `10periodic`, and I disabled the switch 
`APT::Periodic::Update-Package-Lists` by changing its value to `"0"`.

Please note that what I described in this section only applies to an emulated system, where security is not 
a concern, and that we want to minimize performance noise introduced by unrelated applications as much as possible.
On an Ubuntu distribution for daily usage, it is strongly recommended that you should enable automatic update,
and periodically install these updates to keep the system secure.
