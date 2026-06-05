---
title: Dangerous .NET sinks — ASP.NET Core extras
slug: dangerous-dotnet-sinks-extra
aliases: [aspnet-core-sinks, dotnet-core-sinks]
---

{% raw %}

> **TL;DR:** [[dangerous-aspnet-sinks]] covered the .NET Framework classics. This note adds ASP.NET Core / .NET 6+ sinks: Minimal APIs, EF Core raw SQL, System.Text.Json polymorphism, Blazor JS interop, gRPC reflection, Kestrel-specific surfaces.

## Why a sequel note
.NET Core/5+/6+/8+ removed some sinks (`BinaryFormatter` is obsolete and throws by default in .NET 8) and added new ones (polymorphic JSON, Blazor Server interop, Minimal API endpoint filters). Audits that target only the Framework catalogue miss the modern ones.

## Deserialization (Core era)
| Sink | Why dangerous | Note |
|------|---------------|------|
| `JsonSerializer.Deserialize<T>` with `[JsonPolymorphic]` + user-controlled `$type` discriminator | Arbitrary type instantiation | Pin allowed types via `JsonDerivedType` whitelist |
| `BinaryFormatter.Deserialize` | RCE; obsolete API | Throws by default on .NET 8; check `EnableUnsafeBinaryFormatterSerialization` flag |
| `DataContractSerializer` with `KnownTypes` populated from external config | Type confusion | Pin `KnownTypeProvider` |
| `NetDataContractSerializer` | RCE; removed in Core but still in compat shims | Audit Framework→Core ports |
| `MessagePack.Typeless` resolver | Same shape as Newtonsoft `TypeNameHandling.All` | Use `StandardResolver` only |
| Protobuf-net dynamic types | `RuntimeTypeModel` with user-supplied type discriminator | Check schema is static |

## EF Core SQL injection
```csharp
db.Users.FromSqlRaw($"SELECT * FROM Users WHERE name='{userInput}'");     // SQLi
db.Database.ExecuteSqlRaw($"DELETE FROM Sessions WHERE id={id}");          // SQLi
db.Users.FromSqlInterpolated($"SELECT * FROM Users WHERE name={userInput}"); // SAFE — parameterised
```
EF Core 7+: `FromSql` (no `Raw`) treats interpolated args as parameters automatically.

## Minimal APIs
- Parameter binding inference rules surprise auditors: `int id` → from route, `string s` → from query, primitive headers must be `[FromHeader]`. Missing attribute can make a header-only param land as a query string.
- `RouteHandlerFilter` chains: misordered filters can run after the endpoint. Check order in `WithMetadata`.
- `MapPost("/", (Foo f) => ...)` directly binds JSON body → check Foo for mass-assignment surface.

## Blazor / SignalR
- `JSRuntime.InvokeAsync<T>("eval", userInput)` → XSS-equivalent in Blazor Server.
- SignalR hubs: `[Authorize]` is per-class. Per-method gating requires `[HubMethodAuthorize]` or manual `Context.User`. Missing → unauthenticated access to hub methods.
- Blazor Server state is per-circuit on the server; trust boundary is the WS connection. Treat hub params as user input.

## gRPC
- `Greeter.GreeterBase.SayHello` with reflection enabled (`MapGrpcReflectionService` in Program.cs) leaks schema in prod.
- Streaming RPCs without timeout → resource exhaustion ([[grpc-attacks]]).
- Interceptors run after auth check by default; verify pipeline.

## Path / SSRF / file
- `Path.Combine(rootDir, userInput)` does NOT prevent traversal — `userInput="../../etc/passwd"` resolves. Wrap with `Path.GetFullPath` + `.StartsWith(root)`.
- `HttpClient` with `BaseAddress` and user-supplied relative path can pivot to internal hosts.
- `IFormFile.FileName` is attacker-controlled; never use directly in filesystem ops.

## Cryptography
- `RandomNumberGenerator.GetInt32` is CSPRNG. `new Random()` is NOT — flag any auth code using it.
- `Rfc2898DeriveBytes` with SHA1 default + low iterations on .NET 6 — bump to SHA256 + ≥100k iters or use `Argon2` package.
- `Aes` in CBC mode with no MAC → padding oracle.

## Hardening
- Roslyn analyzer pack: `Microsoft.CodeAnalysis.NetAnalyzers` (security rules CA2300–CA2330).
- `<PublishTrimmed>` + `<TrimMode>` link reflection-using sinks at publish — false negatives possible but reduces gadget surface.
- `[ApiController]` + DTOs only at controller boundary; entity binding never crosses controller.

## References
- [Microsoft — ASP.NET Core security topics](https://learn.microsoft.com/en-us/aspnet/core/security/)
- [SecurityCodeScan rules](https://security-code-scan.github.io/#Rules) — Roslyn ruleset
- [Doyensec — .NET deserialization](https://blog.doyensec.com/)
- See also: [[dotnet-code-auditing]], [[dangerous-aspnet-sinks]], [[viewstate-attacks]]

{% endraw %}
