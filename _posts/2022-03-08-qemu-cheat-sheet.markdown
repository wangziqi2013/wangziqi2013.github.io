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

**Convert Image from qcow3 to qcow2**

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

**Installing Packages**

With a system image, new packages can be installed without booting into the system and connecting it to the 
network. This requires `virt-customize` utility, with the command as follows:

```
virt-customize -a [path] --install [package name]
```

where `[path]` is the path to the system image, and `[package name]` is the name of the package as you would have
used with `apt-get install`.