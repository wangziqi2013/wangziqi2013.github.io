---
layout: post
title:  "Understanding Discrete Event Contention Simulation in zSim"
date:   2020-01-22 16:57:00 -0500
categories: article
ontop: true
---

## Introduction

In previous articles of this series, we have covered cache system simulation and its static timing model with the assumption
that only one thread accesses the cache hierarchy at a time. In practice, however, contention may occur at instruction 
and thread level, causing extra delay due to resource hazards. For example, when multiple instructions (uops)
