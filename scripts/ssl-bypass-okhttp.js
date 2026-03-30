/**
 * OkHttp-Specific SSL Pinning Bypass
 *
 * Targeted bypass for apps using OkHttp (v2, v3, v4+).
 * Handles both standard and obfuscated variants.
 *
 * Usage:
 *   frida -U -f com.example.app -l ssl-bypass-okhttp.js
 */

Java.perform(function () {
    console.log("[*] OkHttp SSL Pinning Bypass loaded");

    // ─── OkHttp3+ CertificatePinner.check (standard) ────────────────────────

    try {
        var CertificatePinner = Java.use("okhttp3.CertificatePinner");

        // check(String, List<Certificate>)
        try {
            CertificatePinner.check.overload(
                "java.lang.String",
                "java.util.List"
            ).implementation = function (hostname, peerCertificates) {
                console.log("[+] okhttp3.CertificatePinner.check(String, List) bypassed for: " + hostname);
            };
        } catch (e) {}

        // check(String, Function0) — Kotlin variant in newer OkHttp
        try {
            CertificatePinner.check.overload(
                "java.lang.String",
                "kotlin.jvm.functions.Function0"
            ).implementation = function (hostname, cleanFn) {
                console.log("[+] okhttp3.CertificatePinner.check(String, Function0) bypassed for: " + hostname);
            };
        } catch (e) {}

        // check$okhttp — obfuscated/internal variant
        try {
            if (CertificatePinner["check$okhttp"]) {
                CertificatePinner["check$okhttp"].implementation = function (hostname, fn) {
                    console.log("[+] okhttp3.CertificatePinner.check$okhttp bypassed for: " + hostname);
                };
            }
        } catch (e) {}

        console.log("[+] OkHttp3 CertificatePinner hooks applied");
    } catch (e) {
        console.log("[-] OkHttp3 CertificatePinner not found: " + e.message);
    }

    // ─── OkHttp3 Builder — Remove pinner during client construction ──────────

    try {
        var Builder = Java.use("okhttp3.OkHttpClient$Builder");
        Builder.certificatePinner.implementation = function (pinner) {
            console.log("[+] OkHttpClient.Builder.certificatePinner() bypassed — using empty pinner");
            var EmptyPinner = Java.use("okhttp3.CertificatePinner$Builder")
                .$new()
                .build();
            return this.certificatePinner(EmptyPinner);
        };
        console.log("[+] OkHttp3 Builder hook applied");
    } catch (e) {
        console.log("[-] OkHttp3 Builder hook failed: " + e.message);
    }

    // ─── OkHttp v2 (com.squareup.okhttp) ────────────────────────────────────

    try {
        var OkHttpClient = Java.use("com.squareup.okhttp.OkHttpClient");
        OkHttpClient.setCertificatePinner.implementation = function (pinner) {
            console.log("[+] OkHttp v2 setCertificatePinner bypassed");
            return this;
        };
        console.log("[+] OkHttp v2 hook applied");
    } catch (e) {
        // OkHttp v2 not present — this is expected on modern apps
    }

    try {
        var CertPinnerV2 = Java.use("com.squareup.okhttp.CertificatePinner");
        CertPinnerV2.check.overload(
            "java.lang.String",
            "java.util.List"
        ).implementation = function (hostname, peerCertificates) {
            console.log("[+] OkHttp v2 CertificatePinner.check bypassed for: " + hostname);
        };
    } catch (e) {
        // Expected if OkHttp v2 not present
    }

    // ─── Scan for obfuscated pinners (ProGuard/R8) ──────────────────────────

    try {
        Java.enumerateLoadedClasses({
            onMatch: function (className) {
                if (className.indexOf("CertificatePinner") !== -1 ||
                    className.indexOf("certificatePinner") !== -1) {
                    console.log("[*] Found potential pinner class: " + className);
                }
            },
            onComplete: function () {},
        });
    } catch (e) {
        // Enumeration not critical
    }

    console.log("[*] OkHttp SSL Pinning Bypass complete");
});
