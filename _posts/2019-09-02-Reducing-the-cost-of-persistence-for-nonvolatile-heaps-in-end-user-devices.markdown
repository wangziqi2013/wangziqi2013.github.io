---
layout: paper-summary
title:  "Reducing the Cost of Persistence for Nonvolatile Heaps in End User Devices"
date:   2019-09-02 20:04:00 -0500
categories: paper
paper_title: "Reducing the Cost of Persistence for Nonvolatile Heaps in End User Devices"
paper_link: 
paper_keyword: NVM; Page Coloring; Logging
paper_year: HPCA 2014
rw_set: 
htm_cd: 
htm_cr: 
version_mgmt: 
---

This paper identifies three problems with NVM applications on mobile platforms and manages to solve these problems
with software-only approaches. Applications running on the NVM are classified into two categories. The first category
of application, called NVMCap by the paper, only uses the NVM as an extra chunk of memory, the content of which is 
no longer needed after a crash or system reboot. These applications include those whose use the NVM as a video buffer
or a swap area. The second category is called NVMPersist, which rely on NVM's ability to retain the content of 
application data after a crash or reboot. In practice, these two types of applications often co-exist on the same 
mobile platform, which can introduce subtle problems, either by their own, or because of the subtle interactions
between them. 