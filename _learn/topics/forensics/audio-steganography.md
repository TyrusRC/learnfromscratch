---
title: Audio steganography
slug: audio-steganography
---

> **TL;DR:** Payloads hidden in audio carriers — visible in spectrograms, encoded in LSBs of PCM samples, or transmitted as DTMF / SSTV tones. Open the file in Audacity or Sonic Visualiser before guessing.

## What it is
Audio steganography hides data inside sound files (WAV, MP3, FLAC, OGG). Common channels include the least significant bits of PCM samples, frequency-domain shaping that paints images visible only in a spectrogram, phase encoding, echo hiding, and out-of-band DTMF / SSTV signals. CTF challenges most often use spectrogram text or LSB on uncompressed WAV.

## Preconditions / where it applies
- A carrier audio file is provided or recovered from PCAP / disk.
- The format is lossless (WAV / FLAC) for LSB to survive; lossy codecs destroy LSB but preserve spectrograms.
- Sample rate and bit depth are sufficient to encode the payload — short clips with 16-bit / 44.1 kHz are typical.

## Technique
First inspect visually. In Audacity, switch the track view to **Spectrogram** and widen the frequency window to 0–22 kHz; flag text, QR codes, or images painted in the spectrum. Sonic Visualiser with a custom colour map is sharper for faint marks.

```bash
# DTMF / SSTV decoders
multimon-ng -a DTMF -t wav payload.wav
# Spectrogram from CLI
sox payload.wav -n spectrogram -o spec.png
```

For LSB extraction on PCM WAV, dump samples and read the low bit of each:

```python
import wave
w = wave.open('carrier.wav','rb'); raw = w.readframes(w.getnframes())
bits = ''.join(str(b & 1) for b in raw)
out = bytes(int(bits[i:i+8],2) for i in range(0,len(bits)-7,8))
open('payload.bin','wb').write(out)
```

Tools to try in order: `steghide` (passphrase, JPEG/WAV/AU), `wavsteg` (DeepSound carriers), `stegolsb`, `binwalk` for appended blobs, and `multimon-ng` for FSK/AFSK/DTMF. SSTV images decode with `qsstv` or `slowrx`.

## Detection and defence
- Statistical chi-square or RS analysis on PCM samples flags LSB stuffing — `stegdetect`-style tooling.
- Re-encoding to a lossy codec (Opus, AAC) destroys most LSB and phase-coded payloads.
- Spectrogram anomalies above the speech band (>8 kHz) are obvious to an analyst doing a 30-second visual sweep.
- For DLP, monitor outbound audio uploads from sensitive endpoints; even short clips can exfiltrate keys.

## References
- [Sonic Visualiser](https://www.sonicvisualiser.org/) — spectrogram viewer with custom colour mapping
- [multimon-ng](https://github.com/EliasOenal/multimon-ng) — decodes DTMF, POCSAG, AFSK, and similar tone protocols
- [stego-toolkit](https://github.com/DominicBreuker/stego-toolkit) — collected wrappers around audio + image stego tools
- See also: [[steganography-overview]], [[lsb-steganography]]
