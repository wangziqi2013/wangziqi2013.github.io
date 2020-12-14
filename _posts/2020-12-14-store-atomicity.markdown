---
layout: paper-summary
title:  "Speculative Enforcement of Store Atomicity"
date:   2020-12-14 07:59:00 -0500
categories: paper
paper_title: "Speculative Enforcement of Store Atomicity"
paper_link: https://www.microarch.org/micro53/papers/738300a555.pdf
paper_keyword: Microarchitecture; LSQ; Pipeline; Store Atomicity
paper_year: MICRO 2020
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

This paper proposes a microarchitectural improvement for enforcing store atomicity. Store atomicity, as the paper
shows in later sections, if violated, can make the processor vulnerable to a class of memory consistency problems
that leads to non-serializable global ordering.
Modern processors, unfortunately, often implement the memory consistency model without store atomicity, or only a 
weaker version of it, called "write atomicity", which can incur the same problem as non-store atomicity systems.


