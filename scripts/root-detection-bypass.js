/**
 * Root Detection Bypass for Android
 *
 * Hooks common root detection checks:
 *   - File existence checks (su, Magisk, busybox, Superuser)
 *   - Build.TAGS (test-keys detection)
 *   - System property checks (ro.debuggable, ro.build.type)
 *   - Package manager checks (Magisk, SuperSU apps)
 *   - Runtime.exec("su") detection
 *   - Native file access (libc open/access)
 *
 * Usage:
 *   frida -U -f com.example.app -l root-detection-bypass.js
 */

Java.perform(function () {
    console.log("[*] Root Detection Bypass loaded");

    // Paths commonly checked for root detection
    var ROOT_PATHS = [
        "/system/bin/su",
        "/system/xbin/su",
        "/sbin/su",
        "/data/local/su",
        "/data/local/bin/su",
        "/data/local/xbin/su",
        "/system/app/Superuser.apk",
        "/system/app/SuperSU.apk",
        "/system/etc/init.d/99telekomrooted",
        "/system/xbin/busybox",
        "/system/xbin/daemonsu",
        "/su/bin",
        "/su/bin/su",
        "/sbin/magisk",
        "/data/adb/magisk",
        "/data/adb/modules",
    ];

    // Packages commonly checked
    var ROOT_PACKAGES = [
        "com.topjohnwu.magisk",
        "com.thirdparty.superuser",
        "eu.chainfire.supersu",
        "com.koushikdutta.superuser",
        "com.noshufou.android.su",
        "com.zachspong.temprootremovejb",
        "com.ramdroid.appquarantine",
    ];

    // ─── 1. File.exists() — Hide root-related files ─────────────────────────

    try {
        var File = Java.use("java.io.File");
        File.exists.implementation = function () {
            var path = this.getAbsolutePath();
            for (var i = 0; i < ROOT_PATHS.length; i++) {
                if (path === ROOT_PATHS[i]) {
                    console.log("[+] File.exists() hidden: " + path);
                    return false;
                }
            }
            return this.exists();
        };
        console.log("[+] File.exists hook applied");
    } catch (e) {
        console.log("[-] File.exists hook failed: " + e.message);
    }

    // ─── 2. Build.TAGS — Hide test-keys ──────────────────────────────────────

    try {
        var Build = Java.use("android.os.Build");
        var originalTags = Build.TAGS.value;
        Build.TAGS.value = "release-keys";
        console.log("[+] Build.TAGS changed from '" + originalTags + "' to 'release-keys'");
    } catch (e) {
        console.log("[-] Build.TAGS hook failed: " + e.message);
    }

    // ─── 3. Runtime.exec — Block "su" and "which su" commands ────────────────

    try {
        var Runtime = Java.use("java.lang.Runtime");

        Runtime.exec.overload("java.lang.String").implementation = function (cmd) {
            if (cmd.indexOf("su") !== -1 || cmd.indexOf("magisk") !== -1) {
                console.log("[+] Runtime.exec blocked: " + cmd);
                throw Java.use("java.io.IOException").$new("Permission denied");
            }
            return this.exec(cmd);
        };

        Runtime.exec.overload("[Ljava.lang.String;").implementation = function (cmds) {
            var joined = cmds.join(" ");
            if (joined.indexOf("su") !== -1 || joined.indexOf("magisk") !== -1) {
                console.log("[+] Runtime.exec blocked: " + joined);
                throw Java.use("java.io.IOException").$new("Permission denied");
            }
            return this.exec(cmds);
        };

        console.log("[+] Runtime.exec hooks applied");
    } catch (e) {
        console.log("[-] Runtime.exec hook failed: " + e.message);
    }

    // ─── 4. System.getProperty — Hide ro.debuggable and ro.secure ───────────

    try {
        var SystemProperties = Java.use("android.os.SystemProperties");
        SystemProperties.get.overload("java.lang.String").implementation = function (key) {
            if (key === "ro.debuggable") {
                console.log("[+] SystemProperties.get('ro.debuggable') -> '0'");
                return "0";
            }
            if (key === "ro.build.type") {
                console.log("[+] SystemProperties.get('ro.build.type') -> 'user'");
                return "user";
            }
            if (key === "ro.build.selinux") {
                return "1";
            }
            return this.get(key);
        };

        SystemProperties.get.overload(
            "java.lang.String",
            "java.lang.String"
        ).implementation = function (key, def) {
            if (key === "ro.debuggable") return "0";
            if (key === "ro.build.type") return "user";
            if (key === "ro.build.selinux") return "1";
            return this.get(key, def);
        };

        console.log("[+] SystemProperties hooks applied");
    } catch (e) {
        console.log("[-] SystemProperties hook failed: " + e.message);
    }

    // ─── 5. PackageManager — Hide root apps ──────────────────────────────────

    try {
        var PackageManager = Java.use("android.app.ApplicationPackageManager");
        PackageManager.getPackageInfo.overload(
            "java.lang.String",
            "int"
        ).implementation = function (packageName, flags) {
            for (var i = 0; i < ROOT_PACKAGES.length; i++) {
                if (packageName === ROOT_PACKAGES[i]) {
                    console.log("[+] PackageManager.getPackageInfo hidden: " + packageName);
                    throw Java.use("android.content.pm.PackageManager$NameNotFoundException").$new(packageName);
                }
            }
            return this.getPackageInfo(packageName, flags);
        };
        console.log("[+] PackageManager hook applied");
    } catch (e) {
        console.log("[-] PackageManager hook failed: " + e.message);
    }

    // ─── 6. ProcessBuilder — Block su process creation ───────────────────────

    try {
        var ProcessBuilder = Java.use("java.lang.ProcessBuilder");
        ProcessBuilder.start.implementation = function () {
            var cmds = this.command();
            var cmdStr = cmds.toString();
            if (cmdStr.indexOf("su") !== -1 || cmdStr.indexOf("magisk") !== -1) {
                console.log("[+] ProcessBuilder.start blocked: " + cmdStr);
                throw Java.use("java.io.IOException").$new("Permission denied");
            }
            return this.start();
        };
        console.log("[+] ProcessBuilder hook applied");
    } catch (e) {
        console.log("[-] ProcessBuilder hook failed: " + e.message);
    }

    // ─── 7. Native access() — Hide root files at libc level ─────────────────

    try {
        var accessPtr = Module.findExportByName("libc.so", "access");
        if (accessPtr) {
            Interceptor.attach(accessPtr, {
                onEnter: function (args) {
                    var path = args[0].readUtf8String();
                    if (path) {
                        for (var i = 0; i < ROOT_PATHS.length; i++) {
                            if (path === ROOT_PATHS[i]) {
                                console.log("[+] Native access() hidden: " + path);
                                this.shouldBlock = true;
                                return;
                            }
                        }
                    }
                    this.shouldBlock = false;
                },
                onLeave: function (retval) {
                    if (this.shouldBlock) {
                        retval.replace(-1);
                    }
                },
            });
            console.log("[+] Native access() hook applied");
        }
    } catch (e) {
        console.log("[-] Native access() hook failed: " + e.message);
    }

    console.log("[*] Root Detection Bypass complete — all available hooks applied");
});
