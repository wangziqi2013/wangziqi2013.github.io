---
layout: page
title: Ziqi Wang
permalink: /ziqiw/
---

Resume
------

<embed width="100%" height="1000px" navpanes="0" toolbar="0" statusbar="0" src="{{site.url}}/static/resume.pdf" type="application/pdf" /> 

Research Statement
------------------

I am a PhD student working with Professor [Todd Mowry](http://www.cs.cmu.edu/~tcm/ "Todd Mowry's homepage") 
and [Dimitrios Skarlatos](http://www.cs.cmu.edu/~dskarlat/ "Dimitrios's homepage") since 2017 Fall. 
My research area is computer architecture and memory architecture, especially Hardware Transaction Memory (HTM), Non-Volatile Memory, Memory and Cache
Compression, Cache optimization for serverless & micro-services, and
[Page Overlays](http://users.ece.cmu.edu/~omutlu/pub/page-overlays-for-fine-grained-memory-management_isca15.pdf "Page Overlays").
My research interest also covers concurrent data structure design and parallel computation.

I used to work closely with Processor [Andy Pavlo](http://www.cs.cmu.edu/~pavlo/ "Andy Pavlo's homepage") during my
Masters education at CMU, and my research project was efficient indexing for in-memory databases. 

The goal of my research is to accelerate data access and manipulation on modern general purpose 
multicore architecture. I believe in a hardware-software co-design methodology. The hardware provides specialized 
acceleration capabilities for common cases without sacrificing general purpose processing performance, while the software 
adaptively takes advantage of hardware, and falls back to alternative, slower paths whenever hardware acceleration is 
not achievable.

Research Projects
-----------------

<!--
**(2021.08 - Present)** I am working with Professor Todd Mowry, Dimitrios Skarlatos and Professor Gennady Pekhimenko (U of T) on malloc-less memory allocation for small, short-lived objects.
-->

**(2021.08 - Present)** I am working on the next research project.

**(2020.12 - 2021.08)** I was working with Professor Todd Mowry, Dimitrios Skarlatos and Professor Gennady Pekhimenko (U of T) on memory compression on multi-dimentional address space.

**(2019.05 - 2020.11)** I was working with Professor Todd Mowry on NVM full system persistence.

**(2017.09 - 2019.04)** I was working with Professor Todd Mowry on hardware transactional memory.

**(2017.03 - 2017.07)** As a research associative intern at CMU Institute of Software Research (ISR), I contributed to the 
[Usable Privacy Policy Project (UPPP)](https://www.usableprivacy.org/ "UPPP") under the supervision of Professor Norman Sadeh. 
I implemented a static analysis framework using call graph analysis for Android apps. 

**(2016.04 - 2017.03)** As a Master student at CMU Master of Science in Computer Science program, I contributed to 
[Peloton](https://github.com/cmu-db/peloton "Peloton Github"), an 
open-source self-driving in-memory database system optimized for HTAP workloads. My main contribution is the lock-free B+Tree index, the 
BwTree. I implemented the BwTree based on a [Microsoft Reaearch paper](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/bw-tree-icde2013-final.pdf "BwTree Paper"), and measured its performance under YCSB benchmark.

Publications
------------
**2021**
<br />
Wang, Ziqi, Michael A. Kozuch, Todd C. Mowry, Vivek Seshadri, Gennady Pekhimenko, Chulhwan Choo, Dimitrios Skarlatos. "NVOverlay: Enabling Efficient and Scalable High-Frequency Snapshotting to NVM. " Proceedings of the 48th Intl. Symposium on Computer Architecture (ISCA), Virtual, June 2021.

**2019**
<br />
Wang, Ziqi, Vivek Seshadri, Todd C. Mowry, and Michael Kozuch. ”Multiversioned Page Overlays: Enabling Faster Serializable Hardware Transactional Memory.” In 2019 28th International Conference on Parallel Architectures and Compilation Techniques (PACT). IEEE, 2019.

Zimmeck, Sebastian, Peter Story, Daniel Smullen, Abhilasha Ravichander, Ziqi Wang, Joel Reidenberg, N. Cameron Russell, and Norman Sadeh. ”MAPS: Scaling privacy compliance analysis to a million apps.” Proceedings on Privacy Enhancing Technologies 2019, no. 3 (2019): 66-86. 

**2018**
<br />
Wang, Ziqi, Andrew Pavlo, Hyeontaek Lim, Viktor Leis, Huanchen Zhang, Michael Kaminsky, and David G. Andersen. ”Building a bw-tree takes more than just buzz words.” In Proceedings of the 2018 International Conference on Management of Data, pp. 473-488. ACM, 2018. 

**2017**
<br />
Pavlo, Andrew, Gustavo Angulo, Joy Arulraj, Haibin Lin, Jiexi Lin, Lin Ma, Prashanth Menon, Todd Mowry, Matthew Perron, Ian Quah, Siddharth Santurkar, Anthony Tomasic, Skye Toor, Dana Van Aken, Ziqi Wang, Yingjun Wu, Ran Xian, and Tieying Zhang. ”Self-Driving Database Management Systems.” In CIDR, vol. 4, p. 1. 2017.

Zimmeck, Sebastian, Ziqi Wang, Lieyong Zou, Roger Iyengar, Bin Liu, Florian Schaub, Shomir Wilson, Norman M. Sadeh, Steven M. Bellovin, and Joel R. Reidenberg. "Automated Analysis of Privacy Requirements for Mobile Apps." In NDSS. 2017.

**2016**
<br />
Zimmeck, Sebastian, Ziqi Wang, Lieyong Zou, Roger Iyengar, Bin Liu, Florian Schaub, Shomir Wilson, Norman Sadeh, Steven Bellovin, and Joel Reidenberg. ”Automated analysis of privacy requirements for mobile apps.” In 2016 AAAI Fall Symposium Series. 2016.

Fun Stuff
---------
**OS Kernel** I am interested in implementing my own operating system kernel from the scratch, using a mixture of C and 
assembly. I have made several attempts since undergraduate. In my last try, I successfully implemented 
the bootloader, the keyboard driver, the character-based video driver, and some common facilities. I was stuck,
however, on the file system part. I could not figure out the best way of buffer management, and failed to
build a working file system on top of that. This unfinished project is currently hosted on my 
[Github](https://github.com/wangziqi2016/Kernel) {% include icon-github.html username="wangziqi2016" %}.

**Compiler Generator** I implemented a compiler generator in Python, which supports LR(1) and LALR grammar. The compiler generator also 
allows user to define syntax directed transformation rule, such that the compiler could directly output an Abstract Syntax Tree (AST) 
instead of parse tree. C-specific typedef is also supported using a global symbol table, such that statements like "A * a" will be 
parsed as a pointer definition if symbol "A" has been defined as a type, or as a multiplication expression statement otherwise. The 
source code is available on my [Github](https://github.com/wangziqi2013/CFront) {% include icon-github.html username="wangziqi2013" %}.

ORCID
-----

<div itemscope itemtype="https://schema.org/Person"><a itemprop="sameAs" content="https://orcid.org/0000-0003-0067-0701" href="https://orcid.org/0000-0003-0067-0701" target="orcid.widget" rel="noopener noreferrer" style="vertical-align:top;"><img src="https://orcid.org/sites/default/files/images/orcid_16x16.png" style="width:1em;margin-right:.5em;" alt="ORCID iD icon">https://orcid.org/0000-0003-0067-0701</a></div>

<img src="{{site.url}}/static/ORCID.png" width="200px" />