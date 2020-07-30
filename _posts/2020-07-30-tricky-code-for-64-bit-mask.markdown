---
layout: post
title:  "Knowing Your Hardware ALU Shifter When Generating 64-bit Bit Masks"
date:   2020-07-30 12:45:00 -0500
categories: article
ontop: false
---

Yesterday I was very confused when one of the unit tests in a paper's project failed. Both the unit test and the code to
be tested are extremely simple such that no one would expect a failure to occur. 
The code to be tested is a one-line macro for generating 64-bit masks (of type `uint64_t`)

{% highlight C %}
#define MASK64_LOW_1(num)  ((1UL << num) - 1)
{% endhighlight %}

{% highlight C %}
void test_mask() {
  for(int bits = 0;bits <= 64;bits++) {
    uint64_t value1 = MASK64_LOW_1(bits);
    for(int i = 0;i < 64;i++) {
      if(i < bits) assert(bit64_test(value1, i) == 1);
      else assert(bit64_test(value1, i) == 0);
    }
  }
  return;
}
{% endhighlight %}