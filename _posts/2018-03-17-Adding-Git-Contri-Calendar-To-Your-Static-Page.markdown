---
layout: post
title:  "Adding Dynamic Git Contribution Calendar To Your Static Page"
date:   2018-03-16 10:07:03 -0500
categories: web-dev
---

### Introduction

The contribution calendar is one of the nicest things on Github profile page. For crazy coders
like many of my colleges, there is nothing more suitable to serve the purpose of
showing off their hard work and devotion into the great cause that we call "programming". 
This article aims at solving the problem of porting the dynamic-static Github contribution calendar
onto your personal page. It is "dynamic" because the most recent update of your 
contribution history will be reflected the next time the page is refreshed. No effort of manually
updating the calendar and even the static page itself is ever needed. It is "static" because 
no server-side programming is required. All you need is Javascript and ascynchronous XML HTTP request.
In the following demonstration we use [Github page](https://pages.github.com/) (github.io domain) 
as the content provider. A preview of the final effect is given in Figure 1.

<hr />
![Preview]({{ "/static/contri-calendar/figure1-preview.png" | prepend: site.baseurl }} "Preview"){: width="800px"}
**Figure 1 Preview**
{: align="middle"}
<hr /><br />

**Disclaimer**: I am not a web programmer, and I have not participated into any "serious" web development project.
In the following discussion, incorrect/non-standard/risky practices may be stated in a form that underestimates the
negative effects they can introduce. In addition, my HTML/JS/CSS coding style may also be non-standard or offensive to
real web developers (I write good C/C++/Python, though). If you are unsure whether certain actions will bring about
undesirable consequences, please refrain from conducting them. If extra clarification is needed, please consult a 
professional web developer or any other reliable sources. 

### Related Work

Obviously there are lots of diligent coders who treasure their Github contribution history. And when it comes 
to showing off, people are always motivated and innovative. Among many projects that micmic Github-style
contribution calendar, the one that I like most is
[githubchart-api](https://github.com/2016rshah/githubchart-api), a pure static solution. The 
HTTP server (https://ghchart.rshah.org/[username]) returns a static image that resembles the actual
Github contribution calendar of [username]. The above link can therefore be embedded in an \<img\> tag.
It is also dynamic-static.

Two problems can prevent the above solution from being authentic. First, lacking real HTML elements 
can lead to a few rendering problems. Customization is also impossible. Second, the user experience 
can be rather dull for lack of interaction. Normally, if you hang the mouse pointer over the green grid,
a pop-up tip would appear as shown in Figure 1. On a static picture, however, this is impossible.