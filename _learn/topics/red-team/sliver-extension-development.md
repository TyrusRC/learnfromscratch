---
title: Sliver extension development
slug: sliver-extension-development
aliases: ["sliver-extensions","sliver-armory-extensions"]
date: 2026-06-08
---
{% raw %}
Sliver extensions are how you bolt post-exploitation tooling onto the implant without recompiling it. Three flavours matter in practice: BOFs (COFF object files executed by the `coff-loader` extension), .NET assemblies (run via the `.NET` extension that hosts the CLR), and native shared objects (`.dll`/`.so`/`.dylib`) loaded by the implant itself. The packaging and OPSEC stories differ for each, and the Armory is just a git-backed index that serves the same `extension.json` you would hand-install.

## Manifest anatomy

Every extension is a directory with an `extension.json` and one binary per supported `GOOS/GOARCH`. The schema is small but unforgiving — the server validates it before pushing.

```json
{
  "name": "whoami-ext",
  "command_name": "whoami-ext",
  "version": "0.1.0",
  "extension_author": "tyrus",
  "original_author": "tyrus",
  "repo_url": "https://example.invalid/whoami-ext",
  "help": "Print the current token user via GetUserNameExW",
  "entrypoint": "Run",
  "depends_on": "",
  "init": "",
  "files": [
    { "os": "windows", "arch": "amd64", "path": "whoami.x64.o" },
    { "os": "windows", "arch": "386",   "path": "whoami.x86.o" }
  ],
  "arguments": [
    { "name": "format", "type": "string", "desc": "json|text", "optional": true }
  ]
}
```

Key gotchas:

- `entrypoint` is the exported symbol the loader calls. For BOFs it is the function name (`go` by convention, but Sliver lets you rename it). For .NET it is ignored — the assembly's entry point is used.
- `depends_on` chains another extension. A BOF extension must declare `depends_on: "coff-loader"` or it will not execute.
- `init` runs once on first load; useful for the .NET host to spin up the CLR.

## BOF path

Write the BOF as you would for Cobalt Strike — see [[bof-cobalt-strike-development]] for the calling convention details. The wire format Sliver uses is the same beacon pack: integers, shorts, strings, and binary blobs, length-prefixed. The implant ships `coff-loader` which is a port of TrustedSec's COFFLoader; it resolves `__imp_` thunks against an allowlist of Win32 APIs.

Build:

```bash
x86_64-w64-mingw32-gcc -c whoami.c -o whoami.x64.o \
  -masm=intel -Os -fno-asynchronous-unwind-tables
```

Then drop the `.o` next to `extension.json`, zip the directory, and `extensions load ./whoami-ext.tar.gz` from the client. Sliver pushes the manifest + binary to the implant on first invocation and caches it for the session.

## .NET path

The `.NET` extension hosts the CLR in-process. You hand it a normal assembly (any `Main`-bearing PE) and it runs it on a worker thread with stdout/stderr captured. AMSI and ETW are live in that process unless you patched them earlier — see [[amsi-memory-patching-deep]] and [[etw-tampering-deep]]. The host extension exposes `--amsi-bypass` and `--etw-bypass` flags that patch the well-known byte sequences before invoking the assembly, but those signatures are well-known and shipped detections will fire.

Tradecraft: prefer compiling assemblies with `/platform:anycpu`, strip PDB paths, and avoid `System.Management.Automation` references — they pull the PowerShell engine and trip script-block logging.

## Native shared-object path

For Go or C extensions compiled as a DLL/dylib, the implant `dlopen`s the file and calls the exported `entrypoint`. This runs in-process by default, which is fast but means a crash takes the implant with it. Sliver supports `--process` on the client to spawn a sacrificial host and inject — use it for anything that touches unstable APIs or third-party libraries.

## Shipping via the Armory

The Armory is a list of git repos in `~/.sliver-client/armories.json`. Each repo has an `armory.json` index, signed with a minisign key. To publish:

```bash
minisign -Gm armory.json
git add armory.json armory.json.minisig whoami-ext.tar.gz
git commit -m "add whoami-ext 0.1.0"
git push
```

Clients pin the public key on first add. Rotating the key requires a manual `armory remove` + re-add from every operator, so treat the signing key like a release key.

## OPSEC notes

- In-process extensions inherit the implant's process token, image-load history, and AMSI/ETW state. If you have not unhooked or moved to indirect syscalls ([[syscall-direct-and-indirect]], [[hells-halos-tartarus-gates-comparison]]), the EDR sees every Win32 call the extension makes.
- `coff-loader` allocates RWX for the loaded COFF. Modern EDRs alert on RWX in beacon processes — pre-stage with RW then RX via `VirtualProtect`, or fork the loader to do so.
- .NET extensions trigger `clr.dll`/`mscoree.dll` loads. If your implant lives in a process that has no business hosting the CLR (e.g., `notepad.exe`), the image-load telemetry is a giveaway. Pick a host that already runs managed code, or use the `execute-assembly` style spawn-and-inject flow.
- The Armory transport is plain HTTPS git. Mirror the repos you depend on; do not rely on upstream availability mid-engagement.

For an end-to-end view of where extensions slot into a Sliver engagement see [[sliver-c2-deep]], and for the broader payload toolchain [[osep-payload-development-toolkit]] and [[osep-ad-attack-chain-walkthrough]].
{% endraw %}
