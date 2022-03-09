
---
layout: post
title:  "QEMU Cheat Sheet with Full-System Simulation"
date:   2022-03-18 22:12:00 -0500
categories: article
ontop: true
---

**Convert Image from qcow3 to qcow2**

If QEMU reports error saying "'ide0-hd1' uses a qcow2 feature which is not supported by 
this qemu version: QCOW version 3" (note that ide0-hd1 can be different based on your
startup configuration), then the image is created with a different version of qcow, and
needs to be downgraded. The downgrade command is as follows:

```
qemu-img amend -f qcow2 -o compat=0.10 test.qcow2
```

where `test.qcow2` is the name of the image file.