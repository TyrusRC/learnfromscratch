---
title: Dangerous ASP.NET sinks reference
slug: dangerous-aspnet-sinks
---

> **TL;DR:** Reference list of .NET / ASP.NET APIs that produce RCE, deserialisation, SSRF, path traversal or auth-bypass when fed tainted input. Covers WebForms, MVC, Web API, WCF and modern minimal-API surfaces.

## What it is
.NET inherits a large legacy surface — `BinaryFormatter`, `LosFormatter`, ViewState, WCF NetDataContract. Modern code still hits `Process.Start`, dynamic LINQ, and unsafe deserializers. Reviewers walk this list against decompiled DLLs (dnSpy, ILSpy) or source.

## Preconditions / where it applies
- .NET Framework 2.x–4.8 (WebForms, classic WCF) or .NET Core / .NET 5+ apps
- A request handler — ASPX page, MVC controller action, Web API endpoint, minimal-API delegate, SignalR hub
- Source or decompiled assemblies — ILSpy + dnSpyEx work for both

## Technique

**Deserialisation** — `BinaryFormatter` is RCE-by-design; .NET 5 marked it obsolete, .NET 8 removed it from web frameworks:
```csharp
new BinaryFormatter().Deserialize(stream)        // ysoserial.net TextFormattingRunProperties
new LosFormatter().Deserialize(input)            // WebForms ViewState format
new SoapFormatter().Deserialize(stream)
new NetDataContractSerializer().ReadObject(...)  // WCF
new ObjectStateFormatter().Deserialize(b64)      // ViewState — needs MachineKey
new JavaScriptSerializer(new SimpleTypeResolver()).Deserialize<object>(json)
JsonConvert.DeserializeObject(json, new { TypeNameHandling = All }) // Json.NET
```
ViewState MAC bypass via leaked `machineKey` from web.config = unauth RCE on WebForms.

**Command / process:**
```csharp
Process.Start(filename, args)        // arg-injection via cmd.exe quirks
new Process { StartInfo = { FileName = userPath, UseShellExecute = true } }
```

**Code / expression eval:**
```csharp
CSharpCodeProvider.CompileAssemblyFromSource(...)
Roslyn CSharpScript.EvaluateAsync(input)
DynamicMethod + ILGenerator with user-controlled IL
DataTable.Compute(filter, "")        // SQL-ish expression injection
DataView.RowFilter = userInput
```

**Server.Transfer / Response.Redirect** — open redirect, path traversal into virtual paths:
```csharp
Server.Transfer(userPath)            // can leak ASPX source via ~/web.config tricks
Server.MapPath(userPath)             // path traversal under wwwroot
Response.Redirect(userUrl)           // open redirect if not validated
```

**File / path:**
```
File.ReadAllText / OpenRead, Directory.GetFiles, FileStream(userPath, ...)
Path.Combine(root, userPath)         // Path.Combine drops root when userPath is absolute
ZipFile.ExtractToDirectory(...)      // Zip-Slip
```

**SQL** — string concatenation into:
```
SqlCommand.CommandText = "select " + input
Entity Framework FromSqlRaw / ExecuteSqlRaw with concat
LINQ Dynamic .Where(string) — expression injection
```

**XXE:**
```csharp
new XmlDocument().LoadXml(input)              // pre-4.5.2 default-vulnerable
new XmlTextReader(stream) { DtdProcessing = Parse }
XmlReader.Create with insecure XmlReaderSettings
```

**SSRF / HTTP:**
```
WebRequest.Create(url).GetResponse()
HttpClient.GetAsync(url)
WebClient.DownloadString(url)
```

**WCF specifics:**
- `netTcpBinding` / `wsHttpBinding` with `NetDataContractSerializer` is RCE on tainted input
- Exposed `mex` (metadata exchange) endpoints leak contracts + types

**Minimal API quirks:** model binding to a base type plus `[JsonDerivedType]` can recreate the type-resolver bug if attributes are mis-configured.

## Detection and defence
- Audit `*.config` for `<httpRuntime requestPathInvalidCharacters>`, `<machineKey>` (rotate + protect), and `<deployment retail="true">`
- Replace `BinaryFormatter` with `System.Text.Json` or `DataContractSerializer` with known types
- Set `TypeNameHandling = None` (Json.NET default) and reject `$type` properties
- Use `Path.GetFullPath` + prefix check to defeat traversal in `Path.Combine`
- Run SecurityCodeScan or CodeQL `csharp-security-and-quality` in CI

## References
- [ysoserial.net](https://github.com/pwntester/ysoserial.net) — .NET gadget generator
- [Microsoft — BinaryFormatter obsoletion](https://learn.microsoft.com/en-us/dotnet/standard/serialization/binaryformatter-security-guide) — official guidance
- [HackTricks — ASP.NET tricks](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/aspnet-tricks.html) — sink and bypass patterns
- [SecurityCodeScan rules](https://security-code-scan.github.io/) — Roslyn analyser sink list
