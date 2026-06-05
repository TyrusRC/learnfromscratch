---
title: Android ContentProvider — source audit
slug: android-content-provider-audit
aliases: [content-provider-audit, android-provider-audit]
---

{% raw %}

> **TL;DR:** ContentProviders are the most-leaked IPC surface in Android. Exported providers without permission gates → arbitrary apps read/write your data. SQL injection in `query()` selection strings → table escape. `openFile()` returning `ParcelFileDescriptor` for attacker-controlled paths → path traversal into private files. `grantUriPermissions=true` opens transient-grant surface. Companion to [[android-source-review-methodology]] and [[android-ipc-and-intent-source-audit]].

## Manifest read

```xml
<provider
  android:name=".MyProvider"
  android:authorities="com.example.provider"
  android:exported="true"                  ← is it exposed?
  android:permission="..."                  ← is it gated?
  android:readPermission="..."
  android:writePermission="..."
  android:grantUriPermissions="true">       ← can it issue transient grants?
  <grant-uri-permission android:pathPattern=".*"/>
</provider>
```

Build the table:

| Provider | Exported | Read perm | Write perm | grantUriPermissions | path-patterns |
|---|---|---|---|---|---|

For each provider, open the source.

## The four methods

```java
class MyProvider extends ContentProvider {
    public Cursor query(Uri uri, String[] projection, String sel, String[] selArgs, String sort) { ... }
    public Uri    insert(Uri uri, ContentValues values) { ... }
    public int    update(Uri uri, ContentValues values, String sel, String[] selArgs) { ... }
    public int    delete(Uri uri, String sel, String[] selArgs) { ... }
    public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException { ... }
}
```

## SQL injection — `selection` and `sortOrder`

The classic provider bug: the provider passes user-controlled `selection` (or `sortOrder`) directly into a SQL string.

```java
public Cursor query(Uri uri, ..., String sel, String[] args, String sort) {
    SQLiteDatabase db = mHelper.getReadableDatabase();
    // BAD: sel is attacker-controlled (caller of contentResolver.query)
    return db.query("users", null, sel, args, null, null, sort);
}
```

A caller does:
```kotlin
val c = contentResolver.query(
    Uri.parse("content://com.example.provider/items"),
    null,
    "1) UNION SELECT password, NULL FROM users--",   // injection
    null, null
)
```

Fix patterns:
- Use parameterised statements only (`?` placeholders, args array).
- Restrict `selection` to an allowlist of columns.
- `SQLiteQueryBuilder.setStrict(true)` and `setProjectionMap()` to block surprising columns.
- For modern projects, Room — its compiled queries don't accept arbitrary SQL.

## Path traversal in `openFile`

```java
public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
    String name = uri.getLastPathSegment();
    File f = new File(getContext().getFilesDir(), name);
    return ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY);
}
```

Attacker calls with `content://com.example.provider/../../../databases/secret.db`. `getLastPathSegment()` returns `secret.db`, but if the implementation uses the whole path or doesn't canonicalise, it leaks files.

Canonicalise + bound:
```java
File root = getContext().getFilesDir().getCanonicalFile();
File f = new File(root, name).getCanonicalFile();
if (!f.toPath().startsWith(root.toPath())) throw new FileNotFoundException("escape");
```

## `grantUriPermissions=true`

Sets the provider as "able to grant transient access to specific URIs". A clean use: the app shares a single file URI with the user's selected editor.

The risks:
- `<grant-uri-permission android:pathPattern=".*"/>` — grants over the entire authority, removing the point.
- Code that builds an Intent with `FLAG_GRANT_READ_URI_PERMISSION` for an attacker-controlled URI → the recipient can read whatever the provider serves at that URI.

## URI matchers — a quiet source of confusion

```java
private static final UriMatcher MATCHER = new UriMatcher(UriMatcher.NO_MATCH);
static {
    MATCHER.addURI(AUTHORITY, "items", ITEMS);
    MATCHER.addURI(AUTHORITY, "items/#", ITEM_ID);
}
```

The numeric `#` matches *only* digits. `*` matches any single segment. A provider that uses `*` for an ID-like segment may produce SQL with unexpected types.

Look for path patterns wider than necessary:
```bash
grep -rn 'addURI\|UriMatcher\.\*' src/
```

## FileProvider and external storage

`FileProvider` (androidx) issues `content://` URIs that map to internal file paths. It's safer than raw file:// sharing, but:
- `res/xml/file_paths.xml` defines the mapping. A wide `<external-path name="x" path="."/>` shares the whole storage root.
- A poorly-built FileProvider chain (your app gives a URI to a partner, partner gives it back to a malicious app) can let untrusted code read app-private files.

```bash
find . -name 'file_paths.xml'
```

## Concurrent grants and lifecycle

`grantUriPermission()` calls without matching `revokeUriPermission()` accumulate. On older Android they survived process death; modern Android cleans up but engineering-bug provider lifecycle still keeps grants longer than intended.

## Source-audit checklist

- [ ] Every exported provider either has a `permission=`/`readPermission`/`writePermission` or has a documented "anyone can read these public records" intent.
- [ ] `query()` does not interpolate `selection` / `sortOrder` into raw SQL.
- [ ] `openFile()` canonicalises paths and bounds to a known directory.
- [ ] `grantUriPermissions` is on only when needed and `<grant-uri-permission>` paths are tight.
- [ ] `file_paths.xml` does not share whole storage roots.
- [ ] `Binder#getCallingUid()` checks happen *before* sensitive returns when the provider is internal-only.

## References
- [Android — ContentProvider security](https://developer.android.com/guide/topics/providers/content-provider-creating#Permissions)
- [Android — FileProvider](https://developer.android.com/reference/androidx/core/content/FileProvider)
- [OWASP MASTG — Data storage and privacy](https://mas.owasp.org/MASTG/0x05d-Testing-Data-Storage/)
- See also: [[android-source-review-methodology]], [[android-ipc-and-intent-source-audit]], [[mobile-client-storage-source-audit]]

{% endraw %}
