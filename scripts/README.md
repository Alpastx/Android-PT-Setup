# Frida Scripts

Pre-built Frida scripts for common Android pentesting tasks.

## Scripts

### `ssl-bypass-universal.js`

Universal SSL pinning bypass. Hooks TrustManager, OkHttp, Conscrypt, WebView, and Network Security Config.

```bash
frida -U -f com.example.app -l ssl-bypass-universal.js
```

### `ssl-bypass-okhttp.js`

Targeted bypass for apps using OkHttp (v2, v3, v4+). Handles obfuscated variants and Builder-level interception.

```bash
frida -U -f com.example.app -l ssl-bypass-okhttp.js
```

### `root-detection-bypass.js`

Bypasses common root detection: file checks, Build.TAGS, Runtime.exec, PackageManager, and native `access()`.

```bash
frida -U -f com.example.app -l root-detection-bypass.js
```

## Combining Scripts

Use multiple scripts together:

```bash
frida -U -f com.example.app \
  -l ssl-bypass-universal.js \
  -l root-detection-bypass.js
```

## With objection

You can also use objection for interactive sessions:

```bash
objection -g com.example.app explore
# Then inside:
android sslpinning disable
android root disable
```

## Notes

- Use `-f` (spawn mode) to hook early, before the app initializes its security checks
- Use `-n` (attach mode) if the app is already running
- Some apps use custom pinning — you may need to identify and hook the specific class
- Flutter apps need a different approach (dart:io hooks) — these scripts target Java/Kotlin apps
