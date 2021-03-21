---
layout: page
title: Ziqi Wang
permalink: /ziqiw/
---

Resume
------

<embed width="100%" height="1000px" navpanes="0" src="{{site.url}}/static/resume.pdf" type="application/pdf" /> 

Research
--------

I am a PhD student working with Professor [Todd Mowry](http://www.cs.cmu.edu/~tcm/ "Todd Mowry's homepage") since 2017 Fall. 
My research area is computer architecture and memory architecture, especially [Hardware Transaction Memory (HTM)](https://en.wikipedia.org/wiki/Transactional_memory "Transactional Memory"), Non-Volatime Memory, Memory and Cache
Compression, and
[Page Overlays](http://users.ece.cmu.edu/~omutlu/pub/page-overlays-for-fine-grained-memory-management_isca15.pdf "Page Overlays").
My research interest also covers concurrent data structure design and parallel computation.

I used to work closely with Processor [Andy Pavlo](http://www.cs.cmu.edu/~pavlo/ "Andy Pavlo's homepage") during my
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

**(2017.09 - 2019.04)** I am working with Professor Todd Mowry on page overlays and hardware transactional memory.

**(2019.05 - 2020.11)** I am working with Professor Todd Mowry on page overlays and NVM full system persistence.

**(2020.12 - Present)** I am working with Professor Todd Mowry, Dimitrios Skarlatos and Professor Gennady Pekhimenko on 
memory compression on multi-dimentional address space.

Publications
------------
Pavlo, A., Angulo, G., Arulraj, J., Lin, H., Lin, J., Ma, L., Menon, P., Mowry, T.C., Perron, M., Quah, I. and Santurkar, S., 2017. Self-Driving Database Management Systems. In CIDR.

Zimmeck, S., Wang, Z., Zou, L., Iyengar, R., Liu, B., Schaub, F., Wilson, S., Sadeh, N., Bellovin, S.M. and Reidenberg, J., 2017. Automated analysis of privacy requirements for mobile apps. In Proceedings of the Network and Distributed System Security (NDSS) Symposium (Vol. 2017).

Ziqi Wang, Andrew Pavlo, Hyeontaek Lim, Viktor Leis, Huanchen Zhang, Michael Kaminsky, and David G. Andersen. 2018. Building a Bw-Tree Takes More Than Just Buzz Words. In Proceedings of 2018 International Conference on Management of Data (SIGMOD18). ACM, New York, NY, USA, 16 pages. [https://doi.org/10.1145/3183713.3196895](https://doi.org/10.1145/3183713.3196895)

Peter Story, Sebastian Zimmeck, Abhilasha Ravichander, Daniel Smullen, Ziqi Wang, Joel Reidenberg, N. Cameron Russell, and Norman Sadeh, "Natural Language Processing for Mobile App Privacy Compliance", AAAI Spring Symposium on Privacy Enhancing AI and Language Technologies (PAL 2019), Mar 2019

Sebastian Zimmeck, Peter Story, Daniel Smullen, Abhilasha Ravichander, Ziqi Wang, Joel Reidenberg, N. Cameron Russell, and Norman Sadeh, "MAPS: Scaling Privacy Compliance Analysis to a Million Apps", Privacy Enhancing Technologies Symposium (PETS 2019), 3, Jul 2019

Ziqi Wang, Vivek Seshadri, Todd C. Mowry, and Michael Kozuch. ”Multiversioned Page Overlays: Enabling Faster
Serializable Hardware Transactional Memory.” In 2019 28th International Conference on Parallel Architectures and
Compilation Techniques (PACT). IEEE, 2019.

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