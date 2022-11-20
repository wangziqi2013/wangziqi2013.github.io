---
layout: post
title:  "Cheat Sheet for Building and Deploying SPEC"
date:   2022-11-20 17:54:00 -0500
categories: article
ontop: true
---

# SPEC 2006

## Unpack the Tarball

If you acquired SPEC 2006 in a tarball, the first step is to extract it into a directory:

```
mkdir SPEC2006
cd SPEC2006
tar -xvf [tarball file name]
```

In all the examples below, we assume that SPEC is extracted into directory `SPEC2006`.

## Installing the Tools

SPEC2006 comes with a number of tools that facilitate the building, deploying, and the reporting process.
After extracting SPEC 2006 tarball, the first thing to do is to install the tools. This can be done by
executing the `install.sh` bash script under `SPEC2006` directory. This script will prepare the tools
based on your platform and perform integrity checks of the workload source files. 

If you have modified the source file (which is almost inevitable as we will see later) the integrity check will fail.
The check, however, can be skipped by setting the environmental variable `SPEC_INSTALL_NOCHECK`:

```
export SPEC_INSTALL_NOCHECK=1 
```

This flag will be checked in line 471 of `install.sh`. If the flag is set all integrity checks will be skipped.

