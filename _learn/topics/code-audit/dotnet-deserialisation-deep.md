---
title: .NET deserialisation deep dive
slug: dotnet-deserialisation-deep
aliases: [dotnet-deserialization-deep, csharp-deserialization, json-net-deserialization]
---

> **TL;DR:** .NET deserialisation RCE is well-published but persistently exploited. The serialisers — `BinaryFormatter` (deprecated), `Json.NET` with `TypeNameHandling`, `XmlSerializer` with `XmlElement` type attributes, `DataContractSerializer`, `LosFormatter`, `ObjectStateFormatter` (ViewState), `NetDataContractSerializer`, `SoapFormatter`, `YamlDotNet` — each have insecure modes that, fed attacker bytes, instantiate gadget objects culminating in arbitrary code. Companion to [[deserialisation]] and [[viewstate-attacks]].

## Why .NET deserialisation persists

- **BinaryFormatter** still in widely-deployed legacy systems despite being marked dangerous.
- **TypeNameHandling = Auto/All** in Json.NET is the developer's easy default for polymorphism.
- **ViewState** in older ASP.NET apps inherits the same pattern.
- **Gadget chains** are well-known (ysoserial.net) and easy to weaponise.
- **Microsoft's own products** have had recurring deserialisation CVEs (SharePoint, Exchange, Configuration Manager).

## The serialiser landscape

### BinaryFormatter

The original .NET serialiser. Accepts arbitrary types. Reads type info from the stream.

```csharp
BinaryFormatter bf = new BinaryFormatter();
var obj = bf.Deserialize(stream);
```

If `stream` is attacker-controlled, RCE.

Microsoft has marked obsolete and recommended removal. Many production apps still use.

### Json.NET (Newtonsoft.Json) with TypeNameHandling

```csharp
JsonConvert.DeserializeObject<object>(json, new JsonSerializerSettings {
    TypeNameHandling = TypeNameHandling.All  // dangerous!
});
```

`TypeNameHandling = All` or `Auto` lets the JSON specify the type to instantiate:

```json
{"$type": "System.Diagnostics.Process, System", ...}
```

Combined with gadget chains, RCE.

### XmlSerializer / DataContractSerializer

With `XmlElement` and similar attributes letting type be embedded in the XML, comparable risks.

### LosFormatter / ObjectStateFormatter

Underlie ASP.NET ViewState. Even with MAC validation, certain configurations allow ObjectStateFormatter attacks.

See [[viewstate-attacks]].

### NetDataContractSerializer

Always dangerous — accepts any type. Marked obsolete.

### SoapFormatter

Legacy SOAP/.NET-Remoting serialiser. Comparable to BinaryFormatter.

### YamlDotNet

Polymorphic YAML — `!.NetType: x` tag for instantiation. Dangerous when default-deserialiser allows.

### System.Text.Json (Microsoft's modern)

Default behaviour does NOT allow polymorphic type instantiation. Safer.

But: `TypeInfoResolver` customisation can re-enable.

## Gadget chains

Like Java, .NET has gadget chains: combinations of types whose deserialisation triggers code execution.

`ysoserial.net` provides ready-made payloads:
- `TypeConfuseDelegate`
- `WindowsIdentity`
- `PSObject`
- `TextFormattingRunProperties`
- Many more.

Each works against specific formatters under specific .NET versions.

## Vulnerable patterns to find

### Pattern 1 — User-controlled binary input

```csharp
public IActionResult Upload(IFormFile file) {
    var stream = file.OpenReadStream();
    var bf = new BinaryFormatter();
    var obj = bf.Deserialize(stream);
    return Ok();
}
```

Classic.

### Pattern 2 — Json.NET with TypeNameHandling on user input

```csharp
var data = JsonConvert.DeserializeObject(request.Body, new JsonSerializerSettings {
    TypeNameHandling = TypeNameHandling.Auto
});
```

### Pattern 3 — ViewState without proper validation

ASP.NET WebForms with ValidateRequest=false, no MAC validation key.

### Pattern 4 — SOAP / Remoting endpoints

Public SOAP endpoint with `SoapFormatter` or `BinaryFormatter`.

### Pattern 5 — YAML configuration accepting user-uploaded files

YamlDotNet deserialising user-provided YAML.

## Recent CVEs

- **CVE-2024-21320 / others** — SharePoint deserialisation chain.
- **Multiple Microsoft Configuration Manager** CVEs.
- **Telerik UI** historical deserialisation.
- **Various SharePoint / Exchange** chained with auth bypass.

## Audit shape

For a .NET application:
1. **Grep** for `BinaryFormatter`, `SoapFormatter`, `NetDataContractSerializer`, `LosFormatter`, `ObjectStateFormatter`.
2. **Grep** for `TypeNameHandling` not `None`.
3. **Grep** for `JsonConvert.DeserializeObject<object>` (polymorphic).
4. **Grep** for `XmlSerializer` constructions with attacker-influenced type.
5. **ViewState** validation configuration.
6. **YAML deserialisation** for user content.
7. **SOAP endpoints** for serialiser use.

## Defensive baseline

- **Remove `BinaryFormatter`** completely. Microsoft .NET 7+ throws by default.
- **Json.NET** with `TypeNameHandling = None` always; use polymorphic JSON via explicit converters with type allowlist.
- **System.Text.Json** as preferred default.
- **ViewState** with strong MAC + encryption.
- **Strong-typed deserialisers** (`JsonConvert.DeserializeObject<MyType>(...)`) avoid type pollution.
- **Input validation** — never accept arbitrary serialised input from user.
- **Strip `$type` field** from user input client-side before submission.

## Workflow to study

1. Set up a vulnerable .NET WebForms or API app.
2. Run ysoserial.net to generate payloads.
3. Send against vulnerable serialiser; observe RCE.
4. Switch to safe serialiser; observe attack failure.
5. Read JFrog / Trail of Bits / Black Hat .NET deserialisation talks.

## Tools

- **`ysoserial.net`** — gadget chain generator.
- **`Snyk` / `Sonatype`** — known CVE scanning.
- **`Semgrep`** rules for dangerous patterns.
- **`PVS-Studio`** — static analysis.
- **`SonarQube`** — comprehensive.

## Real-world incidents

- **SharePoint deserialisation campaigns** — multiple disclosed CVEs.
- **Telerik UI** — repeated CVE classes.
- **Microsoft Exchange ProxyLogon** (2021) — deserialisation was part of the chain.
- **Configuration Manager** — multiple CVEs.

## Related

- [[deserialisation]]
- [[java-deserialization-audit]]
- [[viewstate-attacks]]
- [[spring-deserialisation-deep]]
- [[dotnet-code-auditing]]
- [[dangerous-dotnet-sinks]]
- [[dangerous-dotnet-sinks-extra]]

## References
- [Microsoft — BinaryFormatter security guide](https://learn.microsoft.com/en-us/dotnet/standard/serialization/binaryformatter-security-guide)
- [`ysoserial.net`](https://github.com/pwntester/ysoserial.net)
- [JFrog Security Research](https://jfrog.com/blog/)
- [Soroush Dalili — .NET writeups](https://soroush.me/)
- [Alvaro Muñoz — .NET deserialisation talks (Black Hat)](https://www.blackhat.com/)
- See also: [[deserialisation]], [[java-deserialization-audit]], [[viewstate-attacks]], [[dotnet-code-auditing]]
