---
layout: paper-summary
title:  "Firecracker: Lightweight Virtualization for Serverless Applications"
date:   2021-09-18 20:47:00 -0500
categories: paper
paper_title: "Firecracker: Lightweight Virtualization for Serverless Applications"
paper_link: https://www.usenix.org/conference/nsdi20/presentation/agache
paper_keyword: Virtual Machine; Serverless; Lambda
paper_year: NSDI 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
--- 

This paper presents Firecracker, a lightweight VMM platform designed and optimized specifically for serverless. 
This paper contains little technical discussion, especially on the implementations of the Firecracker VMM (it is 
open-sourced, though), and it focuses more on the high-level ideas that motivate the design principals of 
Firecrackers, and how it is deployed in a production system. 
Nevertheless, being able to see an industrial system that has already been tested under production environments 
is always beneficial, and the insights provided by this paper may server as a guideline for future system designers 
working on serverless and other related topics.

Firecracker is motivated by the intrinsic trade-off between isolation and efficiency for general-purpose virtualization
solutions. On one side of the spectrum, containers leverages namespaces, control groups, secure computing 
(seccomp-bpf), and special file systems to allow multiple processes to have their own view of the system, while 
physically they are still sharing the same underlying kernel. Containers have low latency and small memory footprint as
only one kernel image is kept in the memory, but sacrifices isolation, since it entirely relies on the kernel to
isolate processes properly, which may not be hundred percent reliable due to software bugs, side-channels, system
call exploits, etc.

At the other side of the spectrum, virtual machine managers (VMMs) provide hardware-enforced isolation leveraging 
the special CPU mode to allow a full kernel to be executed directly on the hardware as a user process, with the 
hypervisor emulating certain functionalities of privileged instructions and when resource sharing is needed.
VMMs enjoy a higher degree of isolation, since different instances of virtual machines run on different kernel
images. The paper points out, however, that existing fully-fledged VMM implementations face two challenges to 
fulfill the requirements of serverless. First, deployment density of VMMs is lower than that of containers, as each
instance must maintain their own kernel image and a full set of system states for supporting an OS.
Second, startup latency is also a concern, since the VMM needs to boot up a full kernel, which typically takes
seconds.

This paper presents Firecracker, a lightweight VMM implementation targeting running arbitrary binaries without
recompilation on minimum Linux kernel, with an explicit simplicity and minimalism design goal.
Firecracker is implemented in Rust as a middle layer between Linux KVM driver and Linux system calls. 
On the one hand, Firecracker relies KVM to escalate its own permission into that of a hypervisor, and to intercept 
privileged instructions that access shared or system resource. On the other hand, Firecracker relays the access
requests to the host Linux kernel to perform the requested operations, such as I/O and networking, rather than 
implementing its own device driver, reusing the code base of existing Linux.
Firecracker could boot either a minimal Linux kernel, or unikernels designed for cloud applications such as OSv
(despite an earlier claim in the paper that unikernels are unable to support unmodified Linux binaries, OSv actually
supports unmodifed Linux binary, as can be confirmed [here](https://github.com/cloudius-systems/osv/wiki/Components-of-OSv)).
Only a limited set of devices are supported, such as block devices, the network interface, and a few other devices.
Both the disk and network devices have a rate limiter in the Firecracker implemented as token buckets, which regulates
resource consumption of a single VM instance.

Firecracker instances are individual Linux processes, and each process boots one Micro-VM. 
The process communicates with the outside using a local socket and via the REST API. To further fortify the isolation
between Micro-VM instances, Firecracker additionally implements a jailer layer that wraps the middleware, to ensure
that each instance has its own view of the file system, uses a separate namespace, and to limit the available system
calls to Firecracker middleware using seccomp-bpf.

The rest of the paper discusses the big picture of Lambda function infrastructure, and how Firecracker incorporates 
into this big picture. The Lambda infrastructure consists of a frontend worker fleet and a backend worker fleet.
The former is deployed with the API gateway, the load balancer and interfaces that connect with other services,
which receives user requests, queues them, and forwards them to the backend workers. 

