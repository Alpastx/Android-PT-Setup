/**
 * Universal SSL Pinning Bypass for Android
 *
 * Hooks multiple SSL/TLS verification mechanisms:
 *   - TrustManager (Android default)
 *   - OkHttp CertificatePinner
 *   - Conscrypt (modern Android TLS provider)
 *   - Apache HttpClient (legacy)
 *   - WebViewClient SSL errors
 *
 * Usage:
 *   frida -U -f com.example.app -l ssl-bypass-universal.js
 *   frida -U -n "App Name" -l ssl-bypass-universal.js
 */

Java.perform(function () {
    console.log("[*] Universal SSL Pinning Bypass loaded");

    // ─── 1. TrustManager — Accept all certificates ────────────────────────────

    try {
        var TrustManagerImpl = Java.use("com.android.org.conscrypt.TrustManagerImpl");
        TrustManagerImpl.verifyChain.overload(
            "[Ljava.security.cert.X509Certificate;",
            "[B",
            "java.lang.String",
            "java.lang.String",
            "java.lang.String",
            "boolean",
            "[B"
        ).implementation = function (untrustedChain) {
            console.log("[+] TrustManagerImpl.verifyChain bypassed");
            return untrustedChain;
        };
    } catch (e) {
        console.log("[-] TrustManagerImpl not found: " + e.message);
    }

    // ─── 2. X509TrustManager — Bypass checkServerTrusted ─────────────────────

    try {
        var X509TrustManager = Java.use("javax.net.ssl.X509TrustManager");
        var TrustManager = Java.registerClass({
            name: "com.frida.BypassTrustManager",
            implements: [X509TrustManager],
            methods: {
                checkClientTrusted: function (chain, authType) {},
                checkServerTrusted: function (chain, authType) {},
                getAcceptedIssuers: function () {
                    return [];
                },
            },
        });

        var SSLContext = Java.use("javax.net.ssl.SSLContext");
        var sslContext = SSLContext.getInstance("TLS");
        sslContext.init(null, [TrustManager.$new()], null);

        var SSLSocketFactory = Java.use("javax.net.ssl.HttpsURLConnection");
        SSLSocketFactory.setDefaultSSLSocketFactory.call(
            SSLSocketFactory,
            sslContext.getSocketFactory()
        );
        SSLSocketFactory.setDefaultHostnameVerifier.call(
            SSLSocketFactory,
            Java.use("org.apache.http.conn.ssl.AllowAllHostnameVerifier").$new()
        );
        console.log("[+] Default SSLContext replaced with bypass TrustManager");
    } catch (e) {
        console.log("[-] SSLContext bypass failed: " + e.message);
    }

    // ─── 3. OkHttp3 CertificatePinner ────────────────────────────────────────

    try {
        var CertificatePinner = Java.use("okhttp3.CertificatePinner");
        CertificatePinner.check.overload(
            "java.lang.String",
            "java.util.List"
        ).implementation = function (hostname, peerCertificates) {
            console.log("[+] OkHttp3 CertificatePinner.check bypassed for: " + hostname);
        };
    } catch (e) {
        console.log("[-] OkHttp3 CertificatePinner not found: " + e.message);
    }

    // OkHttp3 check$okhttp (obfuscated variant)
    try {
        var CertificatePinner2 = Java.use("okhttp3.CertificatePinner");
        if (CertificatePinner2["check$okhttp"]) {
            CertificatePinner2["check$okhttp"].implementation = function (
                hostname,
                cleanedCerts
            ) {
                console.log(
                    "[+] OkHttp3 CertificatePinner.check$okhttp bypassed for: " + hostname
                );
            };
        }
    } catch (e) {
        // Not present in all OkHttp versions
    }

    // ─── 4. OkHttp (legacy v2) ───────────────────────────────────────────────

    try {
        var OkHttpClient = Java.use("com.squareup.okhttp.OkHttpClient");
        OkHttpClient.setCertificatePinner.implementation = function (pinner) {
            console.log("[+] OkHttp v2 setCertificatePinner bypassed");
            return this;
        };
    } catch (e) {
        // OkHttp v2 not present
    }

    // ─── 5. Conscrypt — OpenSSLSocketImpl ────────────────────────────────────

    try {
        var OpenSSLSocketImpl = Java.use(
            "com.android.org.conscrypt.OpenSSLSocketImpl"
        );
        OpenSSLSocketImpl.verifyCertificateChain.implementation = function (
            certRefs,
            authMethod
        ) {
            console.log("[+] Conscrypt verifyCertificateChain bypassed");
        };
    } catch (e) {
        // Conscrypt not directly accessible
    }

    // ─── 6. WebViewClient — Bypass SSL errors in WebViews ────────────────────

    try {
        var WebViewClient = Java.use("android.webkit.WebViewClient");
        WebViewClient.onReceivedSslError.implementation = function (
            view,
            handler,
            error
        ) {
            console.log("[+] WebViewClient SSL error bypassed");
            handler.proceed();
        };
    } catch (e) {
        console.log("[-] WebViewClient hook failed: " + e.message);
    }

    // ─── 7. Network Security Config — TrustManagerImpl (Android 7+) ─────────

    try {
        var NetworkSecurityTrustManager = Java.use(
            "android.security.net.config.NetworkSecurityTrustManager"
        );
        NetworkSecurityTrustManager.checkServerTrusted.overload(
            "[Ljava.security.cert.X509Certificate;",
            "java.lang.String"
        ).implementation = function (certs, authType) {
            console.log("[+] NetworkSecurityTrustManager.checkServerTrusted bypassed");
        };
    } catch (e) {
        // Not all devices expose this
    }

    // ─── 8. HostnameVerifier — Accept all hostnames ──────────────────────────

    try {
        var HostnameVerifier = Java.use("javax.net.ssl.HostnameVerifier");
        var BypassVerifier = Java.registerClass({
            name: "com.frida.BypassHostnameVerifier",
            implements: [HostnameVerifier],
            methods: {
                verify: function (hostname, session) {
                    return true;
                },
            },
        });
        console.log("[+] HostnameVerifier bypass class registered");
    } catch (e) {
        console.log("[-] HostnameVerifier bypass failed: " + e.message);
    }

    console.log("[*] SSL Pinning Bypass complete — all available hooks applied");
});
