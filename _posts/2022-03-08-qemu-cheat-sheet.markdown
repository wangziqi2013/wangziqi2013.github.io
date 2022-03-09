
---
layout: post
title:  "QEMU Cheat Sheet with Full-System Simulation"
date:   2022-03-18 22:12:00 -0500
categories: article
ontop: true
---

**Creating, Mounting, and Formatting New Image File**

Usually, you need to create a new image file and copy data to it such that the workload files and the dataset,
which can be quite large in certain cases, will not consume storage on the base image (which is often pretty limited).
New images can be created by running the following command:

```
qemu-img create -f qcow2 [path] [size]
```

where `[path]` is the path to the new image you want to create, and `[size]` is the maximum size of the image.
Note that the unit of `[size]` can be specified using `m`/`M`, `g`/`G`, etc.



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