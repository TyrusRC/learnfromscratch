---
title: Blind watermarks
slug: blind-watermarks
---

> **TL;DR:** Frequency-domain marks embedded via DCT / DWT / DFT survive compression and resizing. Recovery without the embedding script is hard — when the challenge provides one, reverse the transform.

## What it is
A blind watermark is a payload embedded into a host image such that extraction does not require the original cover. Encoders shift small amounts of energy in the DCT or DWT coefficients of mid-frequency bands — robust against JPEG recompression, mild crops, and rotation, but invisible to the eye. CTF challenges typically ship the embedding script (e.g. `blind-watermark`, `invisible-watermark`) and the watermarked image; the solver runs the matching decoder.

## Preconditions / where it applies
- A carrier image with suspected hidden text or QR code.
- Usually the challenge provides the encoder source or names the library — recovery without that is brittle.
- Image must not be heavily cropped or downscaled below the watermark's spatial frequency.

## Technique
Identify the library by string-matching against the encode artefacts or the script. Common Python libraries:

```bash
pip install blind-watermark
python -m blind_watermark --decode --pwd_img 1 --pwd_wm 1 \
  --wm_shape 128,64 carrier.png decoded.png
```

`blind-watermark` (guofei9987) splits the image with a DWT, runs a DCT on each block, and stamps a binary watermark across the mid-band coefficients. Decoding needs the **wm_shape** (watermark dimensions) and the two passwords — often `1,1` in challenges. For unknown shapes, sweep common values (64x64, 128x64, 32x32) and look for a coherent QR code.

For raw DCT inspection without the library:

```python
import cv2, numpy as np
img = cv2.imread('carrier.png', 0).astype(np.float32)
dct = cv2.dct(img)
np.save('dct.npy', np.log1p(np.abs(dct)))
```

Visualising the log-DCT often reveals a faint diagonal block — that band holds the mark. Phase-only watermarks (DFT) show as ring artefacts in `np.angle(np.fft.fft2(img))`.

## Detection and defence
- Spectral analysis on a known-clean baseline highlights energy injected into mid-band coefficients.
- Strong JPEG recompression (Q<40), rescaling, and rotation degrade most blind watermarks — adversaries who only need to break the mark, not recover the cover, will batch-process.
- For provenance, layered cryptographic signatures (C2PA) are stronger than perceptual watermarks.

## References
- [blind-watermark library](https://github.com/guofei9987/blind_watermark) — DWT-DCT blind watermark with passwords
- [invisible-watermark](https://github.com/ShieldMnt/invisible-watermark) — used by Stable Diffusion outputs
- [C2PA](https://c2pa.org/) — provenance metadata, the cryptographic alternative
- See also: [[steganography-overview]], [[lsb-steganography]]
