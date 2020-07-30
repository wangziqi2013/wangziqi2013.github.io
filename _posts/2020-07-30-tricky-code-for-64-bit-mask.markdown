---
layout: post
title:  "Knowing Your Hardware ALU Shifter When Generating 64-bit Bit Masks"
date:   2019-07-30 12:45:00 -0500
categories: article
ontop: false
---

Yesterday I was very confused when one of the unit tests in a paper's project failed. Both the unit test and the code to
be tested are extrelely simple such that no one would expect a failure to occur. 
The code to be tested is a one-line macro for generating 64-bit masks (of type `uint64_t`)

