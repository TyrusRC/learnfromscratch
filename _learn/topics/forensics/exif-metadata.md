---
title: EXIF and file metadata
slug: exif-metadata
---

> **TL;DR:** Camera model, GPS coordinates, software fingerprints, thumbnails, and edit history all hide in file metadata. `exiftool` is the first command on any image, PDF, or office document.

## What it is
Most modern file formats carry structured metadata: EXIF / XMP / IPTC in images, `/Info` and XMP in PDFs, `docProps` in Office Open XML, ID3 in MP3, and matroska tags in MKV. The data leaks the originating device, GPS location, software versions, prior crop / edit history (XMP `History:Action`), and sometimes embedded thumbnails that bypass redaction on the visible image.

## Preconditions / where it applies
- A binary file in a format with metadata: JPEG / TIFF / HEIC / RAW, PDF, DOCX / XLSX / PPTX, MP3 / MP4, SVG.
- The file has not been stripped through a converter that drops metadata (re-encoding, screenshots, format conversion).

## Technique
Always start with `exiftool`. It reads ~200 formats including PDF and Office.

```bash
exiftool target.jpg                       # all tags
exiftool -gps:all -ee target.jpg          # geolocation only
exiftool -a -u -g1 target.pdf             # all + unknown + grouped
exiftool -b -ThumbnailImage target.jpg > thumb.jpg     # extract embedded thumb
exiftool -b -PreviewImage target.cr2 > preview.jpg     # RAW preview
```

For Office documents (which are ZIP archives), inspect `docProps/core.xml` and `docProps/app.xml` for author, last-modified-by, edit time, template, and revision count. PDFs additionally carry `/Producer` and `/Creator` strings — those tie a leaked document to a specific PDF library version.

Hidden goldmines:
- **Embedded thumbnails** survive after a user crops or redacts the visible image — the cached thumb still shows the original.
- **GPS in HEIC / iPhone JPEG** — `GPSLatitude`, `GPSLongitude`, `GPSAltitude`, plus `GPSDateStamp`.
- **XMP `History:When` / `History:SoftwareAgent`** in Photoshop / Lightroom — full edit timeline.
- **PDF `/AAPL:Keywords` and `/Producer`** identify macOS Preview, Adobe Acrobat version, or headless renderers like wkhtmltopdf.
- **Maker notes** on DSLR files include serial numbers — useful for de-anonymising stock photos.

Write tools (`exiftool -gps:all=`, `mat2`, `qpdf --linearize`) strip or replace tags but often leave residue in less-known fields.

## Detection and defence
- Run `mat2` or `exiftool -all=` over outbound files in DLP pipelines to strip metadata at the perimeter.
- For redaction, never trust the visible layer — re-render PDFs / images through a flattening converter (`pdf2image` then re-export).
- For OSINT defence on social posts, platforms (Twitter, Instagram) strip EXIF on upload — but Discord and direct image links generally do not.

## References
- [ExifTool](https://exiftool.org/) — Phil Harvey's metadata Swiss-army knife
- [mat2](https://0xacab.org/jvoisin/mat2) — metadata anonymisation tool
- [OWASP WSTG — Review Webpage Content](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/01-Information_Gathering/05-Review_Webpage_Content_for_Information_Leakage) — metadata in web assets
- See also: [[steganography-overview]], [[file-concentration]]
