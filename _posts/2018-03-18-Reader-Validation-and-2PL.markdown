---
layout: post
title:  "Reader Validation and Two Phase Locking"
date:   2018-03-09 03:32:00 -0500
---

Reader validation is where many different HTM and STM designs diverge. In order to understand why and how the 
validatin based concurrency control is designed, and how to reason about it, we take an approach that compares
read-validation based protocol with what we are already familiar with: the 2PL protocol.

