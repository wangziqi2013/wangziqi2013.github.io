---
layout: paper-summary
title:  "MineSweeper: A Clean Sweep for Drop-In Use-after-Free Prevention"
date:   2023-01-23 06:21:00 -0500
categories: paper
paper_title: "MineSweeper: A Clean Sweep for Drop-In Use-after-Free Prevention"
paper_link: https://dl.acm.org/doi/10.1145/3503222.3507712
paper_keyword: malloc; security
paper_year: ASPLOS 2022
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper presents MineSweeper, a memory safety tool that detects use-after-free cases for malloc library with little
overhead on both execution cycles and memory. MineSweeper is motivated by Mark-and-Sweep Garbage Collection (GC)
techniques that detect live references to objects. MineSweeper leverages a similar algorithm to detect potential
use-after-free cases by scanning for pointers that have freed by the application in the application's address space.
