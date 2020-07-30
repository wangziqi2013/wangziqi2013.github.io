---
layout: post
title:  "Knowing Your Hardware ALU Shifter When Generating 64-bit Bit Masks"
date:   2020-07-30 12:45:00 -0500
categories: article
ontop: false
---

Yesterday I was very confused when one of the unit tests in a paper's project failed. Both the unit test and the code to
be tested are extremely simple such that no one would expect a failure to occur. 
The code to be tested is a one-line macro for generating 64-bit masks (of type `uint64_t`) using bit shift and decrement,
as shown below. The unit test simply enumerates all possible cases, and checks the output. `bit64_test()` is another
macro that checks whether a bit is set or not on a given offset. If the bit is set, it returns one. Otherwise it returns 
zero.

**Mask Genetation:**
{% highlight C %}
#define MASK64_LOW_1(num)  ((1UL << num) - 1)
{% endhighlight %}

**Unit Test:**
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

With the assistance of gdb, it took me another 20 seconds to figure out that the failed case occurred when the value of 
test variable `bits` is 64, meaning that all bits in the output `uint64_t` should be set to one.
This finding, however, puzzled me even more: How could this be a failure?

When the macro argument `num` equals 64, `1UL << num` should output zero, since this piece of code is compiled on a 
64-bit x86-64 architectire, where the native register size is 64 bits, and the compiler will map this macro to 
an `shl` (or `sal`, which is essentially the same, since left shifts do not deal with sign bits) 
assembly instruction. Left shifting `0x1UL` by 64 bits will just result in the only bit being shifted out, which
outputs zero.

To confirm my reasoning, I wrote another one line test as follows:

**Unit Test:**
{% highlight C %}
void test_mask2() {
  printf("0x%lX 0x%lX\n", 0x1UL << 64, (0x1UL << 64) - 1);
  return;
}
{% endhighlight %}

The output of this one line test is `0x0 0xFFFFFFFFFFFFFFFF` as expected. 
So the question is, why the original macro failed, but a manual expansion passed the test?

After some investigation, here is the explanation: Intel x86-64 architecture specifies that, for a 64 bit shift instruction,
the explicit or implicit second operand, which is the number of bits to be shifted, will be truncated before sending to 
the ALU. In other words, due to the fact that the native word size is 64 bits, the ALU can handle a shift amount of as 
many as 64, though any 8-bit value (stored in CL implicitly, or given as immediate number explicitly) can be supplied.
Bit 6 and 7 will always be masked off before the ALU performs the shift.
In our case, this translates to `0x1UL << num` outputting `0x1UL` unchanged when the value of `num` is 64, since the
ALU will only see 0 after the 6th bit of value 64 is masked off.

Interesting enough, a side note in the architecture specification states that in the original 16-bit 8086 design, the
shift amount is not masked, meaning that the hardware shifter bahaves more consistently when the shift amount exceeds
the native word bit length. Starting from 80286, the feature is added to ALU, and is kept even when the hardware 
executes in virtual-8086 mode, resulting in a major source of incompatibility, since any 8086 era software that 
generates bit masks assuming the older ALU shifter behavior will fail to execute correctly in some cases.
