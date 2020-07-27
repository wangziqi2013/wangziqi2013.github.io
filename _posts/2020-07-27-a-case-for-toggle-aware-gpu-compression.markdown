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
These integers will be compressed into a smaller field whose length is sufficient to hold the numeric value in the 
uncompressed form. In programs where small integers are frequently used, this will make bits more random after compression,
since the higher bits used to be really predicable before compression, but are no longer present in the compressed form.
Second, most compression algorithms insert metadata inline with compressed data to form a stream of compressed bits, without
any distinc boundary between compressed data and metadata that helps the decompressor to recognize the next code word. 
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


