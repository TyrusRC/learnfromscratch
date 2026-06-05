---
title: .NET / ASP.NET code auditing
slug: dotnet-code-auditing
aliases: [aspnet-code-review, csharp-audit]
---

{% raw %}

> **TL;DR:** ASP.NET audits split into Framework (.NET 4.x, full IIS) and Core (.NET 6+, Kestrel). Same bug families — deserialization RCE, ViewState abuse, SSRF, SQLi via raw queries, Razor SSTI, weak crypto — but the sink names and pipeline shapes differ. Map controllers, find the sinks in [[dangerous-aspnet-sinks]], check the binder for mass-assignment.

## What it is
.NET source review on a Web/MVC/WebAPI app is a high-yield audit target because Microsoft made dangerous defaults easy: `BinaryFormatter` ships in the BCL, `ViewState` MAC is sometimes disabled, EF Core's `FromSqlRaw` is one call away, and Razor's `@Html.Raw` looks innocent. The discipline mirrors [[java-code-auditing]] — enumerate request entry points, classify sinks by impact, trace binders backwards.

## Preconditions / where it applies
- Source (`*.cs`, `*.cshtml`, `*.csproj`) — or decompiled assemblies via dnSpy / ILSpy
- Framework version — .NET Framework 4.x and .NET Core/5+/6+/8+ have different sink surfaces
- Knowledge of ASP.NET routing (`MapControllerRoute`, attribute routing, minimal APIs)

## Technique
1. **Map entry points.**
   - Classic MVC/WebAPI: classes ending in `Controller`, methods with `[HttpGet]/[HttpPost]/[Route(...)]`, `ApiController`.
   - Minimal APIs (.NET 6+): `app.MapGet("/...", (...) => ...)` lambdas in `Program.cs`.
   - SignalR hubs: classes inheriting `Hub`.
   - Web Forms (.NET Framework): `*.aspx.cs` code-behind, `Page_Load`, postback handlers.
2. **Trace sources.** Action parameters bound from `[FromBody]`, `[FromQuery]`, `[FromRoute]`, `[FromForm]`, `[FromHeader]`. Watch `HttpContext.Request.Form/Query/Headers/Body`, `Request.RouteValues`, and Web Forms `Request[...]`. Model-binder reflection means any public setter on a bound model is reachable.
3. **Sink catalogue.** Top-impact list:
```bash
rg -n '\bBinaryFormatter|LosFormatter|NetDataContractSerializer|ObjectStateFormatter|SoapFormatter|JavaScriptSerializer|TypeNameHandling\s*=\s*TypeNameHandling\.(All|Auto|Objects)' .
rg -n 'FromSqlRaw|ExecuteSqlRaw|SqlCommand\(.*\$|new\s+SqlCommand\(\s*\$' .
rg -n 'Process\.Start|new ProcessStartInfo' .
rg -n 'XmlReader\.Create\([^)]*\)|XmlDocument\(\)|DtdProcessing\s*=\s*DtdProcessing\.Parse|XmlResolver\s*=\s*new\s+XmlUrlResolver' .
rg -n '@Html\.Raw|Razor\.Parse|RazorEngine\.Compile|@\{[^}]*\}' .
rg -n 'WebRequest\.Create\(|HttpClient.*\.GetAsync\(\$|HttpClient.*\.PostAsync\(\$' .
```
4. **ViewState (Framework only).** Check `<pages enableViewStateMac="false">` or `<machineKey>` exposed in repo — both lead to `LosFormatter` / `ObjectStateFormatter` RCE. See [[viewstate-attacks]].
5. **Newtonsoft.Json `TypeNameHandling`.** Anything other than `None` plus a `$type` field in attacker JSON = arbitrary type instantiation → deserialization RCE chain. System.Text.Json's `JsonSerializerOptions.TypeInfoResolver` polymorphism is safer but still abusable when type discriminators are user-controlled.
6. **Mass-assignment.** Binding a request body to an EF entity directly (`public IActionResult Update([FromBody] User u)`) exposes every public setter, including `IsAdmin`. Audit DTO/ViewModel boundaries; flag any `_db.Users.Update(u)` on a directly-bound entity.
7. **Razor SSTI.** Server compiles `@(...)` Razor with full C# reflection. If an admin panel does `RazorEngine.Razor.Parse(userTemplate)`, that's RCE. Even `@Html.Raw(userInput)` is XSS, not SSTI — but Razor templates loaded from user-writable storage (DB, S3) is.
8. **Crypto and tokens.** `MD5`/`SHA1` for password hashing, hard-coded `machineKey`, signed tokens without expiry check, JWT `none` allowed (`TokenValidationParameters.ValidateLifetime=false` in audit logs).
9. **Static tooling.** Microsoft DevSkim, SecurityCodeScan (Roslyn analyzer), `dotnet list package --vulnerable` for known-CVE deps, Semgrep `csharp.lang.security`.

## Detection and defence
- Ban `BinaryFormatter` outright (it's obsolete in .NET 8+). Migrate to `System.Text.Json` with disabled polymorphism.
- Use parameterised LINQ / EF Core methods; `FromSqlRaw` only with parameters `{0}` not string interpolation.
- Enforce `DtdProcessing.Prohibit` and `XmlResolver = null` on every `XmlReader` / `XmlDocument`.
- Bind to DTOs, never entities. Use `[Bind]` whitelists for legacy MVC.
- Ship Roslyn analyzers in CI; treat warnings as errors.

## References
- [Microsoft — BinaryFormatter security guide](https://learn.microsoft.com/en-us/dotnet/standard/serialization/binaryformatter-security-guide)
- [Soroush Dalili — .NET serialization research](https://soroush.me/)
- [SecurityCodeScan](https://security-code-scan.github.io/) — Roslyn ruleset
- [HackTricks — ASP.NET](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/iis-internet-information-services.html)
- See also: [[dangerous-aspnet-sinks]], [[dangerous-dotnet-sinks-extra]], [[viewstate-attacks]]

{% endraw %}
