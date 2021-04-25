---
layout: paper-summary
title:  "A Case for Toggle-Aware Compression for GPU Systems"
date:   2020-07-27 02:03:00 -0500
categories: paper
paper_title: "A Case for Toggle-Aware Compression for GPU Systems"
paper_link: https://ieeexplore.ieee.org/document/7446064/citations
paper_keyword: Compression; GPU; Link Compression
paper_year: HPCA 2016
rw_set:
htm_cd:
htm_cr:
version_mgmt:
---

**Highlight:**

1. Using simple formula: (energy * latency) and optional bandwidth utilization (1 / (1 - BU)) to evaluate overall merit 
   of compression
   
2. Recognizes the problem of misaligned compressed words can also cause extra bit flips. This is actually related to value
   locality, which is addressed by BDI. 

3. Redundancy exists in three forms: Literal repetitions of tokens, easily compressible patterns (ones, zeros, repeated 
   patterns, etc.), and value locality. The first can be recognized by dictionary-based algorithm; The second can be recognized
   by FPC; The last can be recognized by locality aware algorithms such as BDI. 
   The paper's metadata consolidation addresses the last form of locality, which may exists in compressed data.
   On the presence of value locality, even compressed words will have bits in common that can be further compressed.

**Questions**

1. How does the EC notifies the receiving end of a compressed/uncompressed line? Does it prepend a special status bit?

2. How does decompression hardware know the boundary between metadata and compressed words? Does the compressor use
   a short field to indicate this?

This paper proposes a compression-based bus transmission scheme for reducing the energy and power consumption while 
retaining the benefits of bandwidth reduction with compression. The recognizes that compressing data before they are
transmitted can reduce the bandwidth of data transmission over the system bus and inter-component links, which is especially 
effective for GPGPU, since GPGPUs are more likely to be memory bound.

This paper points out, however, that transmitting compressed data may consume more power compared with transmissing the 
same amount of uncompressed data, constituting a new trade-off in the compression paradigm. The paper assumes an energy
model in which the amount of energy consumed by the transmissting hardware is proportional to the number of bit flips
from the previous transmission in order to form the current value to be transmitted on the link. The paper also assumes
that the transmission link has a limited bit width, which is usually far smaller than the number of bits in a cache line,
which requires a cache line to be buffered and transmitted in the unit of packets (called "flits"). Under this condition,
the extra power consumption is a result of higher per-bit entropy, meaning that each bit carries more information than 
in the uncompressed case. This is totally natural and unaviodable with compression, since the goal of compression is to 
reduce the number of bits required for storing the same amount of information. 

The paper also identifies two major reasons for increased entropy per bit. First, most compression algorithms eliminate 
redundant zeros or ones at the higher bits of a small integer. 
These integers will be compressed into smaller fields whose length is sufficient to hold the numeric value in the 
uncompressed form. In programs where small integers are frequently used, this will make bits more random after compression,
since the higher bits used to be really predicable before compression, but are no longer present in the compressed form.
Second, most compression algorithms insert metadata inline with compressed data to form a stream of compressed bits, without
any distinct boundary between compressed data and metadata that helps the decompressor to recognize the next code word. 
During decompression, the unstructured stream is intepreted by a hardware state machine which extracts bits from the head
of the stream to recognize the type and layout of the next code word.
As a result, compressed code words are usually misaligned, which further increases the randomness of bits during transmission,
since the transmission protocol still reads in data to be transmitted in regular 8-bit or larger words. 
For example, even with FPC compressed data, small values that are close to each other still preseve their original lower
bit pattern, and are written as the output. If these values are properly aligned, such that these close by values bits
align on the transmitter hardware's pins, then only a subset of pins need to be flipped across transmission packets, since most bits 
in these compressed words are still the same, consuming less energy.
On the contrary, in practice, FPC will insert metadata bits between the compressed words to indicate the type of the 
pattern. This will significantly reduce the chance that bits at the same offset in the encoded words use the same pin,
thus increasing the randomness of bits transmitted on transmitter pins.

The paper also observes two trends from dedicated, mobile and open-source GPU workloads. The first observation is that
the effect of compression on the randomness of bits is more prominent on mobile workloads than on dedicated GPU workloads.
This is because mobile workloads tend to use more integers in its computation, which are more regular, while dedicated 
workloads uses more floating point numbers, which are already random due to their mantissa bits.
The second observation is that the degree of randomness is highly related to the compression ratio. The more compressed
a cache line is, roughly more bit flips it will take to transmis compressed data over the line. This is also consistent 
with the previous argument that compression increases the entropy and hence the randomness of bits.

This paper proposes two mechanisms for evaluating the cost of performing compression and the cost of extra power 
consumption. The first mechanism evaluates the trade-off between performance and power using a formula which takes
all factors into consideration, and selects the scheme that minimizes the formula for each transmission.
The second mechanism proposes that the layout of compressed data should be adjusted such that even compressed words
should be property aligned. We next discuss each of them in details.

The energy-performance trade-off formula needs to take the following three factors into consideration: (1) Compression
reduces the size of data to be transmitted on the memory bus, which reduces latency of memory read and cache write back 
operations; (2) Compression also reduces effective bandwidth consumption of the bus, since less bits are transmitted
and the bus is held for transmission for shorter time, improving the latency for other transactions contending for the bus. 
The bandwidth benefit, however, is non-linear, with less or zero marginal gain near the low bandwidth consumption side. 
In other words, the busier the bus is, the more benefit compression can bring us. When the bus is mostly idle, data 
transmission will not affect the latency of other operations as the level of contention is low; (3) The number of bit 
flips. The formula, which is proposed as (Latency * Energy), fulfills (1) and (3), but not (2), since (2) is non-linear. 
The paper suggests that in order to take bandwidth utilization (BU) into consideration, the value of the formula
is further multiplied by (1 / (1 - BU)), giving more weights to compression ratio over energy consumption. 

One hardware component, called the Energy Control (EC) unit, is added to the data path for eviction and line fetch.
The paper assumes that compressor and decompressor also exist on the data path. When a line is to be transmitted, the
EC unit first compresses the line, obtaining both the compression ratio and the energy consumption (using an XOR
array between flits and an adder tree, as indicated by the paper), and then decides using the above formula
whether the line is transmitted compressed or uncompressed. An extra bit is prepended to the data to indicate the
compression status. Although not mentioned by the paper, the bus controller should also monitor bus bandwidth usage,
and make recent bandwidth usage available for the EC unit in order to derive the value of BU.

The second mechanism is metadata consolidation, which states that the compression metadata should be stored in a separate
part of compressed data, instead of being mixed with encoded words to form a stream. This requires some simple modification
to the compression and decompression hardware, and probably more pipeline stages for scattering or gathering if the 
hardware is pipelined. In addition, extra information should be added to help decompressor recognize the metadata and
data region.
