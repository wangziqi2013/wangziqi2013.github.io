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
the native word bit length. Starting from 80286, the masking feature is added to ALU to reduce instruction latency, and 
is kept even when the hardware executes in virtual-8086 mode, resulting in a major source of incompatibility. 
Any 8086 era software that generates bit masks assuming the older ALU shifter behavior will fail to execute correctly in 
some cases.

As for why the second test case gives the correct answer: When constant numbers are used in an expression, the compiler
will always evaluate the constant expression at compilation time. Unfortunately, gcc's constant evaluation is not properly
programmed to match hardware behavior, although it does prints out a warning saying that the constant shift amount exceeds
the bit length of the source operand:

{% highlight C %}
test.c:104:33: warning: left shift count >= width of type [-Wshift-count-overflow]
   printf("0x%lX 0x%lX\n", 0x1UL << 64, (0x1UL << 64) - 1);
                                 ^
test.c:104:47: warning: left shift count >= width of type [-Wshift-count-overflow]
   printf("0x%lX 0x%lX\n", 0x1UL << 64, (0x1UL << 64) - 1);
{% endhighlight %}

To confirm that gcc constant evaluation does not match hardware behavior, I wrote a test program as follows:

{% highlight C %}
#include <stdio.h>

int main() {
  unsigned long x = 0x1UL << 64;
  printf("%lX\n", x);
  return 0;
}
{% endhighlight %}

The resulting disassembly code after compiling this with default arguments to gcc is as follows:

{% highlight assembly %}
0000000000400526 <main>:
  400526:	55                   	push   rbp
  400527:	48 89 e5             	mov    rbp,rsp
  40052a:	48 83 ec 10          	sub    rsp,0x10
  40052e:	48 c7 45 f8 00 00 00 	mov    QWORD PTR [rbp-0x8],0x0
  400535:	00 
  400536:	48 8b 45 f8          	mov    rax,QWORD PTR [rbp-0x8]
  40053a:	48 89 c6             	mov    rsi,rax
  40053d:	bf e4 05 40 00       	mov    edi,0x4005e4
  400542:	b8 00 00 00 00       	mov    eax,0x0
  400547:	e8 b4 fe ff ff       	call   400400 <printf@plt>
  40054c:	b8 01 00 00 00       	mov    eax,0x1
  400551:	c9                   	leave  
  400552:	c3                   	ret    
{% endhighlight %}

As you can see, the value of `0x1UL << 64` has been evaluated at compilation time, which is zero. `[rbp-0x8]` is just the
stack location of local variable `x`. A different result would occur, if you change the above test code to the following:

{% highlight C %}
#include <stdio.h>

int main() {
  int y = 64;
  unsigned long x = 0x1UL << y;
  printf("%lX\n", x);
  return 0;
}
{% endhighlight %}

The output of this code snippet is `1` instead of `0`, with the disassembly being:

{% highlight assembly %}
0000000000400526 <main>:
  400526:	55                   	push   rbp
  400527:	48 89 e5             	mov    rbp,rsp
  40052a:	48 83 ec 10          	sub    rsp,0x10
  40052e:	c7 45 f4 40 00 00 00 	mov    DWORD PTR [rbp-0xc],0x40
  400535:	8b 45 f4             	mov    eax,DWORD PTR [rbp-0xc]
  400538:	ba 01 00 00 00       	mov    edx,0x1
  40053d:	89 c1                	mov    ecx,eax
  40053f:	48 d3 e2             	shl    rdx,cl
  400542:	48 89 d0             	mov    rax,rdx
  400545:	48 89 45 f8          	mov    QWORD PTR [rbp-0x8],rax
  400549:	48 8b 45 f8          	mov    rax,QWORD PTR [rbp-0x8]
  40054d:	48 89 c6             	mov    rsi,rax
  400550:	bf f4 05 40 00       	mov    edi,0x4005f4
  400555:	b8 00 00 00 00       	mov    eax,0x0
  40055a:	e8 a1 fe ff ff       	call   400400 <printf@plt>
  40055f:	b8 01 00 00 00       	mov    eax,0x1
  400564:	c9                   	leave  
  400565:	c3                   	ret    
{% endhighlight %}

In the disassembly, `DWORD PTR [rbp-0xc]` is the stack location of local variable `y`, which is initialized to 64 (0x40),
while `QWORD PTR [rbp-0x8]` is variable `x`. Before the `shl` instruction, gcc first moves the shift amount into `CL` register
and the shift target into `RDX` (Although `EDX` is actually used, this is an optimization based on the specification that
higher 32 bits of a x86-64 register will be cleared when the lower 32 bits are loaded with a new value).
In this case, it is the hardware ALU, instead of gcc, that evaluates the expression. As expected, bit 6 and 7 of the 
shift amount, which is 64, are masked off, resulting in the actual amount seen by the ALU being zero.