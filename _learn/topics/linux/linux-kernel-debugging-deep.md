---
title: Linux kernel debugging — deep
slug: linux-kernel-debugging-deep
aliases: [linux-kgdb-deep, linux-kernel-debug-deep]
---

> **TL;DR:** Linux kernel debugging combines source-level introspection (KGDB/KDB, QEMU + gdb), dynamic tracing (ftrace, kprobes, bpftrace, eBPF), and post-mortem analysis (kdump + crash). For research and exploitation work the canonical setup is a QEMU-booted kernel with `CONFIG_DEBUG_INFO` and `lx-*` gdb scripts; for production triage it is kdump capturing a vmcore that the `crash` utility walks. This is the practitioner companion to [[linux-kernel-architecture]], [[kernel-exploits-linux]], [[linux-kernel-pwn-walkthrough]], and [[ebpf-offensive-and-defensive]].

## Why it matters

Userland debugging tools (`gdb`, `strace`, `ltrace`) stop at the syscall boundary. Anything below — schedulers, memory managers, drivers, the page cache, networking stacks, namespaces, eBPF runtime — is invisible without kernel-aware tooling. For three audiences in particular this matters:

- **Vulnerability researchers** chasing UAFs, OOB reads, race conditions in syscalls or drivers; see [[kernel-syscall-source-review]] and [[linux-kernel-pwn-walkthrough]].
- **Exploit developers** validating heap layout, slab spraying, and ROP chains under a controllable kernel; see [[kernel-exploits-linux]].
- **DFIR and SRE responders** diagnosing panics, soft-lockups, and rootkit residue on production hosts where a reboot loses the crime scene.

If you only ever `dmesg | grep`, you are leaving 90% of the introspection budget on the table.

## Classes of debugging

### Interactive source-level: KGDB, KDB, QEMU + gdb

`KGDB` is the in-tree kernel debugger stub that speaks the gdb remote serial protocol. `KDB` is the front-end shell that ships alongside it. Together (`CONFIG_KGDB=y`, `CONFIG_KGDB_SERIAL_CONSOLE=y`, `CONFIG_KGDB_KDB=y`) they let you set breakpoints, single-step, and inspect kernel state over serial, USB, or ethernet (`kgdboe`).

For research, almost nobody runs KGDB on bare metal. The default workflow is:

1. Build a kernel with `CONFIG_DEBUG_INFO=y`, `CONFIG_DEBUG_INFO_DWARF5=y` (or DWARF4), `CONFIG_GDB_SCRIPTS=y`, `CONFIG_FRAME_POINTER=y`, `CONFIG_KGDB=y`.
2. Boot it under QEMU with `-s -S` (gdb stub on `tcp::1234`, halt at start) plus `-append "nokaslr console=ttyS0"`.
3. Attach `gdb vmlinux`, `target remote :1234`, `hbreak start_kernel`, `c`.

This is the same loop used in [[linux-kernel-pwn-walkthrough]] and most kernelCTF challenges.

### `lx-*` helper scripts

`scripts/gdb/vmlinux-gdb.py` auto-loads when you `gdb vmlinux` from the kernel build tree. Highlights:

- `lx-ps` — walk `init_task.tasks` and print every `task_struct`.
- `lx-symbols` — re-resolve symbols after a module loads (essential when fuzzing/poking drivers).
- `lx-dmesg` — dump the printk ring buffer without needing a live console.
- `lx-lsmod`, `lx-mounts`, `lx-iomem`, `lx-fdtdump` — the rest of the toolkit.
- `lx-cmdline`, `lx-version` — quick sanity checks against the right vmlinux.

If `lx-*` commands are missing, you forgot `CONFIG_GDB_SCRIPTS=y` or you are pointing gdb at the stripped image. Use the one in the build tree, not `/boot/vmlinuz-*`.

### Sanitizers: KASAN, KFENCE, UBSAN, KMSAN

These are not debuggers — they are bug *catchers* that turn silent corruption into loud splats with stack traces. Pair them with [[building-a-research-home-lab]] fuzzing rigs.

- **KASAN** (`CONFIG_KASAN=y`) — shadow-memory-based detection of OOB and UAF on SLUB/SLAB and page allocator. Three modes: generic (software, heavy), software tags (arm64), hardware tags (arm64 MTE).
- **KFENCE** (`CONFIG_KFENCE=y`) — sampling allocator with guard pages; cheap enough for production. Catches the same bug classes as KASAN but probabilistically.
- **UBSAN** (`CONFIG_UBSAN=y`) — undefined behavior (shifts, integer overflow, array bounds). Cheap and high signal.
- **KMSAN** (`CONFIG_KMSAN=y`, x86_64 only) — uninitialized memory reads. Expensive, but unique coverage; syzkaller relies on it heavily.
- **KCSAN** (`CONFIG_KCSAN=y`) — data races. Useful when chasing the kinds of bugs in [[kernel-exploits-linux]].

### Dynamic tracing: ftrace, kprobes, bpftrace, perf

- **ftrace** — the in-kernel tracer exposed via `/sys/kernel/tracing`. `function_graph` traces every call; `function` is cheaper; `events/syscalls` mirrors strace at line rate. `trace-cmd` and `kernelshark` are the friendly front-ends.
- **kprobes / kretprobes** — patch any kernel instruction with a trap and a handler. The primitive behind almost every dynamic instrumentation tool.
- **uprobes** — same idea for userland symbols; useful when the bug crosses the syscall boundary.
- **bpftrace** — awk-like DSL on top of eBPF + kprobes + tracepoints. Pithy one-liners like `bpftrace -e 'kprobe:vfs_read { @[comm] = count(); }'`.
- **perf** — sampling profiler and tracepoint frontend. `perf top -g`, `perf record -e cycles -g`, `perf trace` (strace-on-steroids).

eBPF deserves its own callout: as a quasi-debugger it lets you attach safe, verified programs to almost any kernel hook without rebooting. See [[ebpf-offensive-and-defensive]] for offensive uses and detection-side instrumentation.

### Post-mortem: kdump + crash

When a production box panics you cannot KGDB it. Instead:

1. `kexec`-loaded **crashkernel** boots on panic and captures `/proc/vmcore` to disk via `makedumpfile`.
2. The **crash** utility (a fork of gdb with kernel-aware commands) loads the vmcore against `vmlinux` and gives you `ps`, `bt`, `log`, `kmem`, `runq`, `mod`, `files`, `vm`, `irq`, etc.
3. For deeper poking, `crash` will drop you to its embedded gdb with `gdb <expr>`.

This is the single most useful skill for [[ir-from-source-signals]]-style kernel-level IR.

## Patterns and process

### Debugging a panic — checklist

1. **Capture everything.** Serial console log, `dmesg`, vmcore if kdump fired, `/var/crash/*`.
2. **Identify the oops type.** `BUG:`, `WARNING:`, `general protection fault`, `unable to handle page fault`, soft-lockup, hung-task, RCU stall — each has different roots.
3. **Decode the address.** `addr2line -e vmlinux <RIP>` or `./scripts/faddr2line vmlinux func+0xNN/0xMM`. With `CONFIG_RANDOMIZE_BASE` you must subtract the KASLR slide first (see `Kernel offset:` in the panic).
4. **Walk the stack.** In `crash`: `bt -a` for all CPUs, `bt -f` for frames with locals, `bt -t` for raw unwound stack words.
5. **Inspect the offender.** `task`, `files`, `vm`, `struct task_struct.thread` — recreate what the task was doing.
6. **Reproduce small.** If you cannot reproduce, instrument with KASAN + KFENCE + KMSAN under syzkaller or a custom harness.

### QEMU integration tricks

- `-kernel bzImage -initrd rootfs.cpio -nographic -append "console=ttyS0 nokaslr oops=panic panic=-1"` — minimal repro VM that dies hard on first oops (good for fuzzing).
- `-s -S` — gdb stub on 1234, halt at boot; pair with `gdb vmlinux` and `target remote :1234`.
- `-cpu host -enable-kvm` for speed when you do not need exact instruction-level determinism; drop KVM when you do.
- `-monitor stdio` then `info registers`, `x/16i $rip`, `info mtree` for cases where the kernel hangs before the gdb stub responds.
- `-chardev socket,id=virtiocon0,path=/tmp/vcon0,server=on,wait=off -device virtio-serial -device virtconsole,chardev=virtiocon0` — virtio-serial console for libvirt-managed VMs where the host wants a unix socket instead of a TCP port.

### libvirt + virtio-serial for fleet-scale work

When you maintain dozens of debug guests, define a `<channel type='unix'>` per domain pointing at `/var/lib/libvirt/qemu/${name}.kgdb.sock` and a matching `virtio-serial` device. Then `socat - UNIX-CONNECT:/var/lib/libvirt/qemu/foo.kgdb.sock` gives you a KGDB pipe from anywhere on the host. Pair with `virsh console` for the regular tty.

## Defensive baseline

For production hosts (not research VMs):

- Enable `kdump` and verify it actually captures a vmcore (`echo c > /proc/sysrq-trigger` in a maintenance window).
- Ship `vmlinux` debuginfo to the same place you ship vmcores; a dump without symbols is barely better than `dmesg`.
- Turn on `CONFIG_KFENCE` and `CONFIG_UBSAN` in production kernels — both are cheap and have caught real bugs.
- Restrict `/proc/kallsyms`, `/sys/kernel/tracing`, and `perf_event_paranoid` per [[detection-engineering-pyramid-of-pain]] expectations; attackers love these for [[kernel-exploits-linux]] reconnaissance.
- Audit who can load eBPF (`CAP_BPF`, `CAP_PERFMON`) — see [[capabilities-privesc]] and [[ebpf-offensive-and-defensive]].
- Forward kernel oopses to your SIEM (`kmsg` -> rsyslog -> SIEM); they are high-signal detections per [[siem-detection-use-case-catalog]].

## Workflow to study

1. **Week 1 — QEMU + gdb basics.** Build a vanilla kernel with `make defconfig kvm_guest.config`, add the debug configs, boot under QEMU, attach gdb, break on `sys_uname`, walk to userland. Reproduce `lx-ps`, `lx-dmesg`.
2. **Week 2 — KASAN.** Build with `CONFIG_KASAN=y`. Write a deliberately-buggy out-of-tree module with a 1-byte OOB write. Watch the splat. Decode it with `faddr2line`.
3. **Week 3 — ftrace + bpftrace.** Trace every `openat` system-wide for 10 seconds with `trace-cmd record -e syscalls:sys_enter_openat`. Reproduce with `bpftrace`. Compare overhead.
4. **Week 4 — kdump + crash.** Configure kdump on a test VM, trigger a panic with sysrq, open the resulting vmcore in `crash`, walk `bt`, `ps`, `log`, `kmem -i`.
5. **Week 5 — exploit harness.** Take a known nday from [[kernel-exploits-linux]] (e.g. a Dirty Pipe variant), build a vulnerable kernel, reproduce under QEMU + gdb, set a breakpoint at the corruption site, watch the slab.
6. **Week 6 — syzkaller.** Stand up `syz-manager` against your QEMU images with KASAN + KMSAN + KCSAN. Triage one crash to a minimal C reproducer.
7. **Week 7 — eBPF debugger.** Write a bpftrace script that flags any `execve` whose parent is `kthreadd` (rootkit smell). Cross-reference [[edr-rules-as-code-from-attack-patterns]].

## Related

- [[linux-kernel-architecture]]
- [[kernel-syscall-source-review]]
- [[kernel-exploits-linux]]
- [[linux-kernel-pwn-walkthrough]]
- [[ebpf-offensive-and-defensive]]
- [[kernel-debugging-with-windbg]]
- [[hevd-stack-overflow-walkthrough]]
- [[capabilities-privesc]]
- [[namespaces-and-cgroups]]
- [[building-a-research-home-lab]]
- [[ir-from-source-signals]]
- [[siem-detection-use-case-catalog]]

## References

- Linux kernel docs — KGDB and KDB: <https://docs.kernel.org/dev-tools/kgdb.html>
- Linux kernel docs — gdb kernel debugging and `lx-*` helpers: <https://docs.kernel.org/dev-tools/gdb-kernel-debugging.html>
- Linux kernel docs — KASAN: <https://docs.kernel.org/dev-tools/kasan.html>
- Linux kernel docs — ftrace: <https://docs.kernel.org/trace/ftrace.html>
- crash utility upstream: <https://crash-utility.github.io/>
- bpftrace reference guide: <https://github.com/bpftrace/bpftrace/blob/master/docs/reference_guide.md>
