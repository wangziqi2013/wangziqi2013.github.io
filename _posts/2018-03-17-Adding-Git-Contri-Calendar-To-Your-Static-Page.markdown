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
<br />
![Preview]({{ "/static/contri-calendar/figure1-preview.png" | prepend: site.baseurl }} "Preview"){: width="800px"}
<br />
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

As said previously, the contribution calendar should consist of real HTML elements. By inspecting into the source code 
of the Github profile page, we should be able to find the HTML element that contains the calendar, as shown in Figure 2.

<hr />
<br />
![HTML Elements]({{ "/static/contri-calendar/figure2-html.png" | prepend: site.baseurl }} "HTML Elements"){: width="800px"}
<br />
**Figure 2: HTML Elements**
{: align="middle"}
<hr /><br />

The entire calendar is wrapped inside an \<svg\> tag. "svg" stands for "Scalable Vector Graph", which is an HTML 5 feature for 
drawing 2D shapes. All elements inside an SVG are treated as HTML DOM objects, and can be accessed programmatically by javascript.
Daily contributions are rendered using the rectangle element, \<rect\>. Attributes of rectangles describe the metadata of the daily 
contribution, such as the contribution date, "data-date", and commit count, "data-count". Daily contributions are grouped together
by the week they are in, using the containter element \<g\>. The entire calendar is then wrapped within a \<g\>. Texts that denote
months and days in a week are drawn using \<text\>. 

An attribute of the outermost \<div\> element in Figure 2 proves to be useful: "data-graph-url". In our example, the Github
user name is "wangziqi2013", and the attribute's value is therefore "/users/wangziqi2013/contributions". If we enter the absolute 
URL "https://github.com/users/wangziqi2013/contributions", the following will show up:

<hr />
<br />
![Graph Data URL]({{ "/static/contri-calendar/figure3-graph-data-url.png" | prepend: site.baseurl }} "Graph Data URL"){: width="400px"}
<br />
**Figure 3: Graph Data URL**
{: align="middle"}
<hr /><br />

Apparently, Figure 3 is the HTML source of Github's contribution calendar with all metadata. Till now, we have solved the static 
part of the problem, i.e. how the elements are orgnized. Next, we focus on the dynamic part and seek ways of inserting the elements and 
metadata into the static page at runtime. 

The technique we employ is called Asynchronous Javascript and XML (ajax). The design is straightforward: when the page is loading,
a request for the aforementioned URL is sent by the browser. On reception of the response, HTML elements that constitute the calendar
are parsed and inserted into the document. On most platforms, the asynchronous request can be handled using the built-in 
XMLHttpRequest (XHR) class.

### Adding CSS

### User Interaction with Javascript