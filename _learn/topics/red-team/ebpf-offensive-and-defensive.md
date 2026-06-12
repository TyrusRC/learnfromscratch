---
title: eBPF — offensive and defensive
slug: ebpf-offensive-and-defensive
aliases: [ebpf-attacks, ebpf-detection]
---

{% raw %}

> **TL;DR:** eBPF runs sandboxed programs in the Linux kernel — for tracing, networking, security. Offensively: BPF-LSM hooks can rootkit syscalls, kprobes can capture credentials, tc programs can inject/drop packets, all without loading a kernel module. Defensively: eBPF-based EDR (Falco, Tracee, Cilium Tetragon) sees what kprobes see. Capability-gated (`CAP_BPF` + `CAP_PERFMON` + `CAP_SYS_ADMIN` for some), but containers with `CAP_BPF` are an escape primitive. Companion to [[container-runtime-escapes-modern]] and [[linux-userland-and-kernel-rootkit-primer]].

## What eBPF can do

- Attach to kprobes / uprobes / tracepoints — observe syscalls, function entry/exit.
- Attach to tc (traffic control) — manipulate network packets.
- Attach to XDP — drop/redirect packets at the driver layer.
- Attach to BPF-LSM — hook security checks.
- Attach to cgroup egress/ingress.
- Attach to socket filters — like classic BPF.

## Offensive uses

### 1. Userland rootkit (libbpfgo / aya)

```go
// pseudocode
program := loadEBPFProgram("hide_pid.bpf.o")
attach(program, "sys_enter_getdents64", filterPID(rootkitPID))
```

The program intercepts `getdents64` syscalls and removes the rootkit's PID from results. `ps`, `top`, `ls /proc` no longer show it.

This is more powerful than LD_PRELOAD — affects statically-linked binaries too.

### 2. Network exfiltration

Attach a tc-egress program that:
- Identifies packets matching a target (e.g., DNS queries).
- Tags the payload with hidden data via TCP options or length padding.
- Lets it through normally.

Defender sees normal traffic; attacker decodes the side-channel.

### 3. Credential interception

Attach uprobe to `OpenSSH` or `sudo`:
```c
SEC("uprobe/sshd:do_auth")
int trace_auth(struct pt_regs *ctx) {
    char buf[64];
    bpf_probe_read_user(buf, sizeof(buf), (void *)PT_REGS_PARM2(ctx));
    bpf_printk("password: %s", buf);
    return 0;
}
```

Logs every authentication attempt's password to kernel ringbuffer.

### 4. Container escape

A container with `CAP_BPF` can load eBPF programs in the host kernel namespace. From there:
- Modify packet flows to access host network.
- Trace host processes to extract credentials.
- BPF-LSM hooks could deny host security checks (with `CAP_SYS_ADMIN`).

## Defensive uses

### 1. Syscall observability

Falco / Tracee load eBPF programs that observe every syscall and emit events when patterns match a rule. Real-time alerts:
- `exec` of `/bin/sh` from a container that normally runs only `nginx`.
- `connect()` to an external IP from a Pod with no egress requirement.
- `setuid()` to root from a non-privileged context.

Output is JSON; pipe to SIEM.

### 2. Network policy enforcement

Cilium uses eBPF to enforce K8s NetworkPolicies at the kernel level — faster than iptables, more flexible (L7 awareness).

### 3. Anti-forensic detection

Rootkits that hide files / processes via LD_PRELOAD or kernel modules are visible to eBPF programs operating *below* their hooks. Falco can be configured to alert on the gap ("ps shows N processes; eBPF sees N+1").

## Capabilities required

| Capability | Required for |
|---|---|
| `CAP_BPF` (since 5.8) | Loading eBPF programs |
| `CAP_PERFMON` | Tracing / kprobes |
| `CAP_SYS_ADMIN` | Some attach points; legacy fallback |
| `CAP_NET_ADMIN` | tc / XDP programs |

A normal container has none. A privileged container has all.

## Detection of malicious eBPF

eBPF programs are loaded via the `bpf()` syscall. Defenders watch for:
- Non-system processes calling `bpf()`.
- New tracepoints attached at runtime (`/sys/kernel/debug/tracing/`).
- BPF program IDs that don't match an allowlist.

```bash
# List loaded eBPF programs
bpftool prog list
# Map them to processes
bpftool prog show
```

## The verifier

eBPF programs are verified at load time:
- Bounded loops (no infinite).
- Bounded memory accesses (no out-of-bounds).
- Type-safe pointer arithmetic.
- Total instruction count limit.

Bugs in the verifier have produced kernel CVEs (e.g., CVE-2021-3490 — type confusion). Modern kernels have hardened the verifier significantly.

## Source audit

For an eBPF program (offensive or defensive):
- What programs load? `bpftool prog list`.
- What capabilities are required? Are they granted to the right processes?
- BPF-LSM rules — are they restrictive enough?

## CI/CD signal

If a repository has `.bpf.c` files or `libbpf` deps:
```bash
find . -name '*.bpf.c' -o -name 'BPF*.c'
grep -rn 'libbpf\|cilium/ebpf\|aya' .
```

For untrusted eBPF code in CI builds: pin BPF skeleton versions; review each.

## Falco rule example

```yaml
- rule: Unexpected eBPF Load
  desc: Detect bpf syscall from non-allowlisted processes
  condition: >
    syscall.type=bpf
    and not proc.name in (allowlisted_bpf_loaders)
  output: "eBPF loaded by %proc.name (uid=%user.uid container=%container.id)"
  priority: WARNING
  tags: [process, ebpf]
```

`allowlisted_bpf_loaders` includes `falco`, `bpftool`, your EDR's daemon.

## OSCP/OSEP relevance

OSEP: not directly, but Linux post-exploitation tradecraft against eBPF-equipped EDR requires understanding what it sees.
OSEE / advanced kernel exploitation: BPF verifier bugs are real LPE primitives.

## References
- [Brendan Gregg — eBPF observability](https://www.brendangregg.com/ebpf.html)
- [Cilium project](https://cilium.io/)
- [Falco documentation](https://falco.org/docs/)
- [bpftrace](https://github.com/iovisor/bpftrace)
- [eBPF.io reading list](https://ebpf.io/get-started/)
- See also: [[container-runtime-escapes-modern]], [[linux-userland-and-kernel-rootkit-primer]], [[kernel-syscall-source-review]], [[edr-rules-as-code-from-attack-patterns]], [[cilium-tetragon-falco-runtime]]

{% endraw %}
