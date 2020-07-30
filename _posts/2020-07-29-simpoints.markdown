---
layout: paper-summary
title:  "Automatically Characterizing Large Scale Program Behavior"
date:   2020-07-29 18:02:00 -0500
categories: paper
paper_title: "Automatically Characterizing Large Scale Program Behavior"
paper_link: https://dl.acm.org/doi/10.1145/605397.605403
paper_keyword: Debugging; SimPoints
paper_year: ASPLOS 2002
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Note: Source code of SimPoints is available, which contains the full implementation, and should serve as the ultimate
source of reference. This paper summary is merely based on what was written on the published paper, not on what is in
the code repo (things might have changed, or the author did not give full clarification to certain details)**

This paper introduces SimPoints, a simulation tool for accelerating architecture simulation using basic block vectors.
SimPoints aims at solving the problem of architectural simulation, especially cycle-accurate simulation, taking too much 
time to finish on typical full-scale workloads. 

