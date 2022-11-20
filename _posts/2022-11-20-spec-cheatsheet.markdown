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

## Exporting Environmental Variables

After `install.sh` completes, users will be prompted to export SPEC-related environmental variables using 
the following command:

```
export ./shrc
```

After executing the script, a series of variables in the form of `SPEC*` will be added to the current shell
session's environment.

## Preparing Configuration Files

The last step before compilation is to prepare a configuration file that guides the building process to 
use the correct set of tools and options. SPEC 2016 comes with a comprehensive set of configuration files
under `config` directory. You can either modify an existing one, or use one as a template and write your own.

The configuration files contains several options that are critical for the building process:

`tune` and `ext` -- These two will affect the output directory of compiled binary.

`CC`, `CXX` and `FC` -- These three should be updated to match the C compiler, C++ compiler, and Fortran
compiler on your platform.

`PORTABILITY` -- Extra compilation flags can be passed to the compiler by adding them to this option. There
are also per-workload flags that you can set, which are located below this flag.