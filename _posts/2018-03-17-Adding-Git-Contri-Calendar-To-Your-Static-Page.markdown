---
layout: post
title:  "Adding Dynamic Github Contribution Calendar To Your Static Page"
date:   2018-03-16 10:07:03 -0500
categories: web-dev
ontop: true
---

### Introduction

The contribution calendar is one of the nicest things on Github profile page. For crazy coders
like many of my colleges, there is nothing more suitable to serve the purpose of
showing off their hard work and devotion into the great cause that we call "programming". 
This article aims at solving the problem of porting the dynamic-static Github contribution calendar
onto your personal page. It is "dynamic" because the most recent update of your 
contribution history will be reflected the next time the page is refreshed. No effort of manually
updating the calendar and even the static page itself is ever needed. It is "static" because 
no server-side programming is required. All you need is Javascript and ascynchronous XML HTTP request (XHR).
In the following demonstration we use [Github page](https://pages.github.com/) (github.io domain) 
as the content provider. A preview of the final effect is given in Figure 1.

<hr />
![Preview]({{ "/static/contri-calendar/figure1-preview.png" | prepend: site.baseurl }} "Preview"){: width="800px"}
**Figure 1: Preview**
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
to showing off, people are always motivated and innovative. Among many projects that mimic Github-style
contribution calendar, the one that I like most is
[githubchart-api](https://github.com/2016rshah/githubchart-api). The 
HTTP server, https://ghchart.rshah.org/[username], returns a static image that resembles the actual
Github contribution calendar of [username]. The above link can therefore be embedded in an \<img\> tag.
This solution is also dynamic-static.

Two problems can prevent the image-based contribution calendar from being authentic. First, lacking real HTML elements 
can lead to a few rendering problems. Customization is also impossible. Second, the user experience 
can be rather dull for lack of interaction. Normally, if you hang the mouse pointer over the green grid,
a pop-up tip would appear as shown in Figure 1. A static picture, however, does not interact with users.

### Methodology

Compared with image-based frontend or server-side backend approach, we strive to fulfill the following three requirements
at the same time. First, the static content should be dynamic. This implies acquiring data from Github as the 
static page loads using asynchronous requests. Second, the contribution calendar should consist of HTML elements, 
and look excatly identical to the one on Github. This implies re-using the building blocks that Github profile page is
written of, such as the HTML element layour and CSS settings. As we shall see later, it is helpful to look into the 
source of Github page. Lastly, the calendar should be interactive. This suggests implementing event listeners for the 
green grids. In this article, only mouse enter and mouse leave events are implemented as shown in Figure 1.

In the following sections, we present an implementation of the contribution calendar in static HTML, CSS and javascript.
We first show how to insert the HTML elements dynamically. Then we show how to write the CSS for appropriately rendering 
these HTML elements. Finally, we add event handlers to support mouse events. A demonstration of the overall
effects is uploaded to [my Github page](https://wangziqi2013.github.io/).

### Obtaining HTML Elements

### Adding CSS

### User Interaction with Javascript