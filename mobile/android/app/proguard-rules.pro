# ─── Moongate ProGuard / R8 rules ────────────────────────────────────────────
#
# Why this file exists:
#   mobile_scanner 7.x ships a consumerProguardFiles entry but its rules use
#   `com.google.mlkit.*` (single dot) which only matches the immediate
#   `com.google.mlkit` package - NOT the subpackages where the actual ML Kit
#   barcode scanner classes live (com.google.mlkit.vision.barcode.*, etc.).
#   On release builds R8 was therefore stripping ML Kit internals and the
#   scanner crashed at first use with an obfuscated NPE
#   (`Attempt to invoke virtual method 'k5.d k5.c.a(g5.b)' on a null object
#   reference`).
#
# These rules keep the entire ML Kit + barhopper + mobile_scanner surface so
# nothing accessed via reflection gets dropped.

# ── ML Kit (bundled barcode scanner) ──────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Barhopper is the native barcode detector backbone used by ML Kit.
-keep class com.google.android.libraries.barhopper.** { *; }

# ── mobile_scanner Flutter plugin ─────────────────────────────────────────────
-keep class dev.steenbakker.mobile_scanner.** { *; }

# ── CameraX (mobile_scanner uses reflection in places) ────────────────────────
-keep class androidx.camera.** { *; }

# ── Enum reflection (ML Kit + Kotlin) ─────────────────────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── Suppress warnings for classes we keep ─────────────────────────────────────
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.libraries.barhopper.**
-dontwarn com.google.android.gms.internal.mlkit_**
