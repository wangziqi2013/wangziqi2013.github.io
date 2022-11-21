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

## Compiling Workloads

SPEC 2006 workloads can be compiled by invoking the following command under the top-level directory:

```
runspec action=build config=[Your config file name, without ./config directory name and .cfg suffix] [target]
```

The target of compilation can be `all`, which means compiling all workloads. It can also be a space separated 
list of workloads that you wish to build.

## Compilation Errors

SPEC 2006 is a rather old benchmark and is likely incompatible with current releases of gcc.
Consequently, a few workloads would fail to compile, including (on my own machine) 
400.perlbench(base), 416.gamess(base), 447.dealII(base), 450.soplex(base), and 483.xalancbmk(base).

There are online resources that focus on fixing these issues, such as 
[this Github repo](https://github.com/mollybuild/RISCV-Measurement/blob/master/Install-CPU2006-on-unmatched.md).

Many errors can be fixed by adding the following compiler flags to the `PORTABILITY` option in the configuration file:

```
-std=gnu++98 -include cstdlib -include cstring
```

## Finding Output Binary

After compilation, the output binary can be found under the following directory:

```
benchspec/CPU2006/[workload name, e.g., 403.gcc]/run/build_base_amd64-m64-gcc42-nn.0000/[workload name, e.g., gcc]
```

Note that `build_base_amd64-m64-gcc42-nn.0000` is generated based on `tune` and `ext` options in the configuration
file. The trailing `.0000` is the version of binary.

## Running Workloads Manually

Before invoking the workload binary, first switch the current working directory to the input directory 
(which can be achieved with `chdir()` programmatically):

```
benchspec/CPU2006/[workload name, e.g., 403.gcc]/data/ref/input/
```

Then you can invoke the binary with the input file name under the directory. 

Note that there are several workloads that accept inputs from `stdin` (`gamess`, `milc`, `gobmk`, and `leslie3d`). 
For these workloads, the input file must be fed to the `stdin` of the process.
If you are using bash, then it can be easily done with `<` redirection.
If you are doing it programmatically, first open the file using `open()` system call and obtain a file 
descriptor `fd`. Then replace the current process's `stdin` using `dup2()` system call:

```
dup2(fp, FILENO_STDIN);
```

# SPEC 2017

Building and deploying SPEC 2017 is almost identical to those of SPEC 2006. The biggest difference is that
the build command should use `runcpu` instead of `runspec`. 
Besides, the configuration file has a definition `%define label mytest`, which is used to generate the 
output directory for the compiled binary.

After compilation, the output binary is located at:

```
benchspec/CPU/[workload name, e.g., 502.gcc_r]/exe/[build name, e.g., cpugcc_r_base.mytest-m64]
```

SPEC 2017 also has two workloads (`bwaves` and `roms`) that accept inputs from `stdin`.

## Running Workloads Manually

Most workloads in SPEC 2017 can be executed by switching to the input file directory, and invoke the 
binary. 
However, several workloads need special attention when running manually (e.g., `fotonik3d_r`, `roms_r`, `wrf_r`). 
These workloads need input files that are not located in the `data/refrate/input` directory. Instead, you need to 
copy files in `data/all/input` into `data/refrate/input` before invoking the binary.
For `fotonik3d_r`, the tarball `OBJ.dat.xz` should also be extracted to `OBJ.dat`.