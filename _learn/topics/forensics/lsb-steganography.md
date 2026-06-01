---
title: LSB steganography
slug: lsb-steganography
---

> **TL;DR:** Payload bits replace the least-significant bit of pixel channels — invisible to the eye, detectable by chi-square / RS statistics, recoverable by reading the LSBs in scan order.

## What it is
Least-significant-bit (LSB) stego encodes a payload by overwriting bit 0 of each colour channel in a raster image (or each PCM sample in audio). At 8-bit depth the visual change is one part in 256 — imperceptible. Capacity is large: a 1024x1024 RGB PNG carries ~393 KB before any compression. The catch: LSB stego only survives **lossless** containers (PNG, BMP, TIFF, WAV). JPEG re-quantises DCT coefficients and destroys spatial-domain LSBs.

## Preconditions / where it applies
- Carrier is a lossless image (PNG, BMP, TIFF) or PCM audio.
- The embedder used a known scan order (row-major across R,G,B is the default).
- For password-protected variants (`steghide`, `outguess`), a dictionary or known passphrase.

## Technique
Try the well-known tools first; they cover ~90% of CTF challenges.

```bash
zsteg -a carrier.png                       # all bit/channel combinations
zsteg -E b1,rgb,lsb,xy carrier.png > out   # extract one specific plane
stegsolve carrier.png                      # GUI bit-plane viewer
steghide extract -sf carrier.jpg -p ''     # JPEG, prompts for passphrase
stegseek carrier.jpg rockyou.txt           # parallel steghide cracker
```

When the tool list does not match, decode manually. Read LSBs across the image in row-major order, group into bytes, and look for a length prefix or magic header:

```python
from PIL import Image
img = Image.open('carrier.png'); px = img.load()
bits = []
for y in range(img.height):
    for x in range(img.width):
        r,g,b = px[x,y][:3]
        bits += [r&1, g&1, b&1]
b = bytes(int(''.join(map(str,bits[i:i+8])),2) for i in range(0,len(bits)-7,8))
open('payload.bin','wb').write(b[:4096])
```

Variants to try when the obvious scan fails: column-major order, only one channel (often the blue plane), every Nth pixel (`zsteg -E b1,b,lsb,xy --step 2`), or seeded PRNG over pixel positions (need the seed). For JPEG, look at **DCT-domain LSB** (`jsteg`, `outguess`, `f5`) — those modify quantised coefficients and survive JPEG.

## Detection and defence
- Chi-square and RS analysis (Fridrich) detect LSB stuffing — `stegdetect`, `aletheia`. Random LSBs make pixel-value pairs (2k, 2k+1) equiprobable, which differs from natural images.
- Re-encoding through a lossy codec or even a "save-as" round trip in Photoshop destroys LSB payloads.
- DLP can flag PNG / BMP attachments above a size baseline for the visible content.

## References
- [zsteg](https://github.com/zed-0xff/zsteg) — PNG / BMP LSB scanner with channel sweep
- [stegseek](https://github.com/RickdeJager/stegseek) — fast steghide brute-forcer
- [Aletheia](https://github.com/daniellerch/aletheia) — statistical steganalysis suite
- See also: [[steganography-overview]], [[audio-steganography]], [[blind-watermarks]]
