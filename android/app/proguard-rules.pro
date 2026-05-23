# Keep rules for ditto_live 5.x release builds.
#
# Without these, R8 strips classes that libdittoffi.so reflects on, and
# release builds break in two stages:
#
#   1. SIGABRT pre-main, "Cannot initialize rustls without SDK class loader"
#      (failure inside ditto_sdk_transports_set_android_context).
#   2. Once symptom 1 is fixed, TLS handshake silently fails because
#      `org.rustls.platformverifier.CertificateVerifier` is missing.
#      App launches with empty UI; no sync. Logcat shows
#      "failed to call native verifier" + "playground mode authentication
#      failed".
#
# Tracked in SDKS-3594 (workaround / replication) + SDKS-2626 (long-term:
# ship consumer-rules.pro from the SDK so apps don't need this file).
# v4 shipped these via the SDK; v5 dropped them in the KMP rewrite.
#
# Sources for the specific keeps:
#   - live.ditto.** + org.rustls.platformverifier.** + dontwarn-Transient
#     from SDKS-3594's confirmed end-to-end workaround (Kris Johnson,
#     2026-04-29, against quickstart PR #274 + ditto_live 4.14.4-rc.3).
#   - com.ditto.** (KMP namespace) + kotlin.jvm.functions.Function*
#     from Sergiu Bulzan's revised Kotlin v5 rules (#docs, 2026-05-08).
#
# Remove this file once SDKS-2626 lands and ditto_live's published artifact
# carries the rules itself.

-keep class live.ditto.** { *; }
-keep class com.ditto.** { *; }
-keep, includedescriptorclasses class org.rustls.platformverifier.** { *; }
-keep class kotlin.jvm.functions.Function* { *; }
-dontwarn kotlinx.serialization.Transient
