---
title: iOS IPA structure
slug: ios-ipa-structure
---

> **TL;DR:** An IPA is a ZIP containing `Payload/Target.app/` with the Mach-O binary, `Info.plist`, `embedded.mobileprovision`, `_CodeSignature/CodeResources`, embedded frameworks, and resources — every offline analysis starts by understanding which artefact tells you what about the build's provenance, entitlements, and what's encrypted.

## What it is
The iOS App Store distributes apps as `.ipa` files: a ZIP archive with a fixed layout. The substantive content lives under `Payload/<AppName>.app/`. Compared to Android's APK, an IPA carries richer signing/provenance metadata in the bundle (the provisioning profile, capability entitlements) and the main binary is FairPlay-encrypted on Store builds but not on enterprise / TestFlight / dev builds.

## Preconditions / where it applies
- Any iOS reversing or AppSec analysis. Works on dev / enterprise / decrypted-from-jailbreak builds offline.
- For Store builds you need a decrypted dump first (see [[ios-reverse-overview]]).

## Technique
**1. Unpack.**
```bash
unzip -o Victim.ipa -d victim/
tree -L 3 victim/Payload/
```

Standard layout:
```
Payload/Victim.app/
├── Victim                      # Mach-O main binary (the executable)
├── Info.plist                  # bundle metadata (CFBundleID, version, URL schemes)
├── embedded.mobileprovision    # signed provisioning profile (CMS PKCS#7)
├── _CodeSignature/CodeResources # SHA-256 of every file in bundle
├── PkgInfo                     # 8-byte legacy bundle-type marker
├── Frameworks/                 # embedded *.framework / *.dylib bundles
├── PlugIns/                    # app extensions (*.appex)
├── Assets.car                  # compiled image catalog
├── *.lproj/                    # localised resources
└── <other resources>
```

**2. Read `Info.plist`.** Binary plist — convert first.
```bash
plutil -convert xml1 -o - Payload/Victim.app/Info.plist | less
```
Pull out:
- `CFBundleIdentifier` — the app's bundle ID, used in keychain access groups and URL routing.
- `CFBundleURLTypes` → `CFBundleURLSchemes` — custom URL schemes (deep-link entry points; parallel to [[android-deeplink-abuse]]).
- `NSAppTransportSecurity` — `NSAllowsArbitraryLoads`, per-domain exceptions; reveals which HTTPS pinning may be bypassed.
- `UIBackgroundModes`, `NSCameraUsageDescription`, etc. — privacy-sensitive entitlements.
- `MinimumOSVersion`, `DTPlatformBuild` — target iOS + Xcode build.

**3. Inspect `embedded.mobileprovision`.** CMS-signed XML.
```bash
security cms -D -i Payload/Victim.app/embedded.mobileprovision > profile.plist
plutil -p profile.plist
```
Useful fields:
- `Entitlements` — the requested entitlement set; compare against the binary's actual entitlements (`codesign -d --entitlements - Payload/Victim.app/Victim`).
- `ProvisionedDevices` — non-empty means ad-hoc / development build (UDID whitelist).
- `Name`, `TeamIdentifier`, `AppIDName` — provenance.
- `get-task-allow` = true → debuggable build, often dev or enterprise.

**4. Mach-O headers.**
```bash
otool -hv Payload/Victim.app/Victim          # arch, flags
otool -l Payload/Victim.app/Victim | less     # load commands
otool -L Payload/Victim.app/Victim            # linked libs / frameworks
file Payload/Victim.app/Victim                # fat / universal slices
lipo -info Payload/Victim.app/Victim          # arch list
```
`LC_ENCRYPTION_INFO_64.cryptid == 1` means FairPlay-encrypted; you need a decrypted dump to reverse anything in `__TEXT`. `LC_CODE_SIGNATURE` references the embedded signature blob.

**5. Code signature & resource manifest.**
```bash
codesign -dvvv Payload/Victim.app/Victim
codesign -d --entitlements - Payload/Victim.app/Victim
codesign --verify --verbose=4 Payload/Victim.app/
```
`_CodeSignature/CodeResources` lists every bundled resource with a SHA-256; tampering any resource invalidates the signature.

**6. Common interesting files inside the bundle.**
- Embedded JS / HTML for hybrid apps (Cordova, React Native — `main.jsbundle`).
- `.car` asset catalog — extract with `acextract`.
- `.nib` / `.storyboardc` — compiled UI; `ibtool` for inspection.
- `.strings` — localised text; often leaks debug labels.

**7. Frameworks / plugins.** Each `*.framework` and `*.appex` repeats the same Mach-O + Info.plist + signature pattern; treat them as separate analysis targets. App extensions run in their own process with a different entitlement set — often the path of least resistance.

## Detection and defence
- Strip debug symbols (`strip -S`) and disable `get-task-allow` for production builds.
- Refuse to launch if `_CodeSignature` is missing or `codesign --verify` fails (the system already does this for installed apps, but in-process checks help against repacked Frida-Gadget builds).
- Encrypt sensitive bundle resources (config JSON, secrets) and decrypt at runtime with Secure Enclave keys rather than shipping plaintext.

## References
- [Apple — Bundle Programming Guide](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/) — canonical layout
- [OWASP MASTG — iOS basic app analysis](https://mas.owasp.org/MASTG/iOS/0x06b-Basic-Security-Testing/) — bundle inspection workflow
- *macOS and iOS Internals, Volume I* — Jonathan Levin; Mach-O + code-signing chapters
