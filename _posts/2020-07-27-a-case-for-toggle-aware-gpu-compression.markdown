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
same amount of uncompressed data, constituting a new trade-off in the compression paradigm. The extra power consumption 
is a result of higher per-bit entropy, meaning that each bit carries more information than in the uncompressed case.
This is totally natural and unaviodable with compression, since the goal of compression is to reduce the number of bits
required for storing the same amount of information. The paper also identifies two major reasons for increased entropy
per bit. First, most compression algorithms eliminate redundant zeros or ones at the higher bits of a small integer. 
These integers will be compressed into a smaller field whose length is sufficient to hold the numeric value in the 
uncompressed form. In programs where small integers are frequently used, this will make bits more random after compression,
since the higher bits used to be really predicable before compression, but are no longer present in the compressed form.

