---
title: WSL and WSL2 as attack vector
slug: wsl-and-wsl2-as-attack-vector
aliases: ["wsl-tradecraft","wsl2-evasion"]
date: 2026-06-08
---
{% raw %}

WSL is a developer convenience that ships a parallel userland with its own kernel, its own process tree, and its own opinions about logging. On a hardened Windows endpoint, that parallel world is frequently the softest surface in the building. The host EDR was bought to inspect NT processes and PE images. WSL2 hands you a Linux VM behind `vmcompute.exe`, a 9P file bridge, and a NAT'd network stack, and most shops have never written a single detection for any of it.

## The execution model that matters

WSL1 was a pico-process shim translating Linux syscalls to NT. WSL2 is a real Linux kernel inside a lightweight Hyper-V utility VM managed by `vmcompute.exe`. From the host's perspective a running distro is a child of `wslhost.exe` and `vmmemWSL`; from the guest's perspective it is a normal Linux box. ELF processes inside the VM do not appear in Sysmon `EventID 1` with meaningful command lines, do not load PE images the user-mode EDR hooks, and do not trigger AMSI. See [[amsi-bypass]] and [[etw-bypass]] for why that matters.

```
PS> Get-Process vmmemWSL,wslhost,vmcompute
PS> wsl -l -v
  NAME            STATE           VERSION
  Ubuntu-22.04    Running         2
  kali-rolling    Stopped         2
```

The Plan 9 redirector (`\\wsl$\<distro>\` and `\\wsl.localhost\<distro>\`) is the bridge. Anything you drop there is readable from both sides. Defender on Windows will scan PE writes there; it will not, by default, scan an ELF being staged into `/root` from a `\\wsl$` UNC path, and it will not run YARA against memory inside the VM.

## Tradecraft

The interesting moves all start with `wsl.exe` already being a signed, allow-listed Microsoft binary. See [[living-off-the-land]] and [[applocker-bypass-techniques]] - publisher rules for `%SYSTEM32%\wsl.exe` and `%SYSTEM32%\lxss\*` are nearly universal in dev shops.

Stage a Linux toolchain into a developer host without touching `cmd.exe` or PowerShell beyond the launcher:

```
wsl --install -d Ubuntu-22.04 --no-launch
wsl --import dev C:\Users\Public\dev rootfs.tar.gz --version 2
wsl -d dev -u root -- /opt/impl/agent
```

`wsl --import` is the most underrated primitive. You bring your own rootfs tarball - prebuilt with your implant, your C2 profile, your `iptables` rules - and register it as a distribution under any path the user can write. No MSIX, no Store, no admin. The imported distro inherits the host user's network identity for outbound traffic, which is exactly what you want for [[pivoting-and-tunneling]] into the corporate LAN. Pair with [[chisel]] or [[ligolo-ng]] inside the Linux userland and you have a tunnel that the host EDR sees only as `vmmemWSL` sending bytes.

Persistence inside the distro is trivial: `/etc/wsl.conf` `[boot] command=`, systemd units, or a `.bashrc` for the dev user. The host has no equivalent of `Get-ScheduledTask` for any of it.

Reaching the host network is the payoff. WSL2 NATs through a Hyper-V virtual switch; with `mirrored` networking mode (now default on Win11 23H2+) the guest sees the host's interfaces directly and can hit RFC1918 neighbours without `localhost` gymnastics. Even on NAT mode, `ip route` plus the host's default gateway is one `nmap` away.

## The visibility gap

This is the part defenders underestimate. There is a `Microsoft-Windows-Subsystem-Lxss` ETW provider, but it is sparse and not enabled by default in mainstream EDR configs. Sysmon does not parse `vmcompute` child trees usefully. Defender's behavioural engine treats the VM as opaque. The signals that actually fire are:

- `wsl.exe --import` and `wsl.exe --install` command lines on the host (Sysmon EID 1, 4688).
- File writes to `%LOCALAPPDATA%\Packages\*LxssManager*` and `%LOCALAPPDATA%\lxss\` (EID 11).
- Registry writes under `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\` enumerating new distro GUIDs.
- Network: large sustained flows from `System` process owned by `vmmemWSL` egressing to non-update destinations.

Hunt for `wsl --import` with a tarball path outside `Program Files`. Hunt for new GUIDs under the Lxss key without a corresponding Store install. Hunt for ELF magic bytes (`7F 45 4C 46`) written to `\\wsl$` shares from host processes that have no business doing that.

## Hardening posture

If you do not need WSL, disable the optional feature via `Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux,VirtualMachinePlatform`. If you need it, set an enterprise policy: `.wslconfig` with `kernel=` pinned to a signed image, disable `mirrored` networking, and require `wsl --update` via WSUS. AppLocker DLL rules on `lxss*.dll` are worth the noise. Consider an EDR that has a Linux agent and push it inside the distro as part of the gold image - the only honest way to close the gap is to put a sensor where the ELF actually runs.

Related: [[dll-side-loading]], [[edr-hooks-and-unhooking]], [[syscall-direct-and-indirect]], [[osep-payload-development-toolkit]], [[domain-fronting-and-cdn-abuse]].

{% endraw %}
