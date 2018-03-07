---
layout: page
title: Ziqi Wang
permalink: /ziqiw/
---

Research
--------

I am a PhD student working with Professor [Todd Mowry](http://www.cs.cmu.edu/~tcm/ "Todd Mowry's homepage") since 2017 Fall. 
My research area is computer architecture and memory architecture, especially [Hardware Transaction Memory (HTM)](https://en.wikipedia.org/wiki/Transactional_memory "Transactional Memory"), and
[Page Overlays](http://users.ece.cmu.edu/~omutlu/pub/page-overlays-for-fine-grained-memory-management_isca15.pdf "Page Overlays").
My research interest also covers concurrent data structure design and parallel computation.

I was working closely with Processor [Andy Pavlo](http://www.cs.cmu.edu/~pavlo/ "Andy Pavlo's homepage") during my
Masters education at CMU, and my research project was efficient indexing for in-memory databases. 

The goal of my research is to provide efficient data manipulation capabilities based on modern general purpose 
multicore architecture. I believe in a hardware-software co-design methodology. The hardware provides specialized 
acceleration capabilities for common cases without sacrificing general purpose processing performance, while the software 
adaptively takes advantage of hardware, and falls back to alternative, slower paths whenever hardware accelaration is 
not achievable.

Projects
--------

**(2016.04 - 2017.03)** As a Master student at CMU Master of Science in Computer Science program, I contributed to 
[Peloton](https://github.com/cmu-db/peloton "Peloton Github"), an 
open-source self-driving in-memory database system optimized for HTAP workloads. My main contribution is the lock-free B+Tree index, the 
BwTree. I implemented the BwTree based on a [Microsoft Reaearch paper](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/bw-tree-icde2013-final.pdf "BwTree Paper"), and measured its performance under YCSB benchmark.

**(2017.03 - 2017.07)** As a research associative intern at CMU Institute of Software Research (ISR), I contributed to the 
[Usable Privacy Policy Project (UPPP)](https://www.usableprivacy.org/ "UPPP") under the supervision of Professor Norman Sadeh. 
I implemented a static analysis framework using call graph analysis for Android apps. 

**(2017.09 - Present)** I am working with Professor Todd Mowry on page overlays and hardware transactional memory.

Publications
------------

Fun Stuff
---------
**OS Kernel** I am interested in implementing my own operating system kernel from the scratch, using a mixture of C and 
assembly. I have made several attempts since undergraduate. In my last try, I successfully implemented 
the bootloader, the keyboard driver, the character-based video driver, and some common facilities. I was stuck,
however, on the file system part. I could not figure out the best way of buffer management, and failed to
build a working file system on top of that. This unfinished project is currently hosted on my 
[Github](https://github.com/wangziqi2016/Kernel) {% include icon-github.html username="wangziqi2016" %}.

**Compiler Generator** I implemented a compiler generator in Python, which supports parsing LR(1) and LALR grammar. The compiler generatoe also allows user to define syntax directed transformation rule, such that the compiler could directly output an Abstract Syntax Tree (AST) instead of syntax tree. C-specific typedef is also supported using a global symbol table, such that statements like "A * a" will be parsed as a pointer definition if symbol "A" has been defined as a type, or as a multiplication expression statement otherwise. The source code is available on my [Github](https://github.com/wangziqi2013/CFront) {% include icon-github.html username="wangziqi2013" %}..
