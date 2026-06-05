---
title: iOS Objective-C runtime and Swift bridging — source audit
slug: ios-objc-runtime-bridging-audit
aliases: [objc-runtime-audit, swift-bridge-audit]
---

{% raw %}

> **TL;DR:** Mixed Obj-C / Swift apps inherit Obj-C's dynamic runtime: method swizzling, dynamic selectors, `objc_msgSend` to arbitrary classes, `class_addMethod`, KVO key paths from user input. Each is a viable injection or RCE primitive in older codebases. Modern Swift can side-step most of this — *unless* it bridges via `@objc` for backward compatibility. Companion to [[ios-source-review-methodology]].

## What to grep

```bash
grep -rn '@objc\|@objcMembers' .
grep -rn 'NSSelectorFromString\|performSelector\|class_addMethod\|method_exchangeImplementations' .
grep -rn 'method_swizzle\|objc_setAssociatedObject\|objc_getAssociatedObject' .
grep -rn 'NSClassFromString\|class_getMethod\|objc_msgSend' .
grep -rn 'valueForKey\|setValue\(_:forKey:\)\|valueForKeyPath\|setValue\(_:forKeyPath:\)' .
```

## Pattern 1 — selector injection

```objc
SEL sel = NSSelectorFromString(userInput);
if ([self respondsToSelector:sel]) {
    [self performSelector:sel withObject:arg];     // BAD: attacker picks the selector
}
```

If `userInput` flows from a URL parameter, deep link, or JSON, the attacker chooses which method runs. Even with `respondsToSelector:` gating, you've reduced the boundary to "any method on `self`" — usually still bad.

Swift equivalent:
```swift
let sel = NSSelectorFromString(rawSelector)
view.perform(sel, with: arg)
```

Pattern to flag: any `Selector` value derived from a string that came from outside.

## Pattern 2 — KVC / KVO injection

```swift
object.setValue(json["value"], forKeyPath: json["key"] as! String)
```

`setValue:forKeyPath:` lets an attacker set arbitrary properties on the object — including ones the developer never intended exposing. Variant on mass assignment.

Trap: `valueForKeyPath:` from a string lets the caller traverse the object graph (`children.first.password` etc.).

## Pattern 3 — method swizzling

```objc
Method orig = class_getInstanceMethod([UIViewController class], @selector(viewDidLoad));
Method new  = class_getInstanceMethod([self class], @selector(my_viewDidLoad));
method_exchangeImplementations(orig, new);
```

Swizzling itself isn't a bug — it's how many analytics SDKs work. But:
- Two SDKs swizzling the same selector → undefined order; bugs.
- A `+load` method that swizzles before the rest of the app initialises can break invariants.
- Swizzles that bypass authentication or logging are a *backdoor* primitive — search for those.

Audit:
- `+load` and `+initialize` implementations swizzling.
- Multiple swizzles of the same selector.
- Swizzles of `-[NSURLSession dataTaskWithRequest:completionHandler:]` (TLS interception).

## Pattern 4 — `NSClassFromString` instantiation

```swift
let cls = NSClassFromString(name) as? UIViewController.Type
cls?.init()
```

If `name` is user-controlled, the attacker picks the class — possibly one whose initialiser has side effects (filesystem writes, network calls, IPC).

Mitigation: switch on an allowlist of class names you intend to expose.

## Pattern 5 — `NSCoding` / `NSSecureCoding` over the wire

```swift
let data = try Data(contentsOf: untrustedURL)
let archiver = try NSKeyedUnarchiver(forReadingFrom: data)
archiver.requiresSecureCoding = false    // BAD
let obj = archiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
```

`requiresSecureCoding = false` permits any `NSCoding` class to decode — gadget chains identical in shape to Java/PHP deserialisation, just with iOS classes. Always use `decodeObject(of:forKey:)` with an explicit class allowlist.

```bash
grep -rn 'requiresSecureCoding\|decodeObject\(forKey:' .
```

## Pattern 6 — `performSelector` with delay / on thread

```swift
view.perform(NSSelectorFromString(sel), with: arg, afterDelay: 0)
```

Delayed dispatch makes the selector run in a fresh runloop tick — code review and dynamic analysis miss the path. Same attacker-chosen-selector concern.

## Pattern 7 — associated objects with user-controlled keys

```objc
objc_setAssociatedObject(self, (__bridge void *)key, value, OBJC_ASSOCIATION_RETAIN);
```

If `key` comes from user input, the attacker can collide with internal associations and silently overwrite them. Use stable static pointers as keys.

## Swift specifics

Swift's value types and strict typing make many of the above bugs less common — but if the API surface is exposed to Obj-C (subclassing `NSObject`, `@objcMembers`, optional protocol methods), the dynamic semantics return.

A clean Swift-only stack is much easier to reason about. A red flag: a "modern Swift app" with `@objc` annotations everywhere is operating under Obj-C's runtime semantics, including the gotchas above.

## Source-audit checklist
- [ ] No `performSelector:` / `NSSelectorFromString` from user input.
- [ ] No `setValue:forKeyPath:` from user input.
- [ ] Method swizzling, if used, is documented and ordered (use `dispatch_once` and check for prior swizzles).
- [ ] No `NSClassFromString` instantiation of attacker-supplied class names.
- [ ] `NSKeyedUnarchiver` always with `requiresSecureCoding = true` and explicit class allowlists.
- [ ] `+load` / `+initialize` not doing anything dangerous unconditionally.

## References
- [Apple — Objective-C Runtime Reference](https://developer.apple.com/documentation/objectivec/objective-c_runtime)
- [Apple — NSSecureCoding](https://developer.apple.com/documentation/foundation/nssecurecoding)
- [Mike Ash — Friday Q&A series on runtime](https://www.mikeash.com/pyblog/) (general reference)
- See also: [[ios-source-review-methodology]], [[ios-ipc-xpc-audit]], [[deserialisation]]

{% endraw %}
