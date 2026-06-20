# Flutter Core Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase & R8 De-obfuscation Rules
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# RevenueCat Purchases Rules
-keep class com.revenuecat.purchases.** { *; }

# 🚀 TELL R8 TO IGNORE MISSING PLAY STORE DEFERRED CORE CLASSES
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Keep the base embedding classes intact just in case
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }