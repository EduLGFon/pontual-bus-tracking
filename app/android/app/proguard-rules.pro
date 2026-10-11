# Stock Flutter release keeps. The app has no reflection of its own;
# plugins register through GeneratedPluginRegistrant, kept below.
# If a tagged AAB misbehaves on first install, flip minify/shrink
# off in build.gradle.kts and rebuild (documented rollback).
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class com.spotnik.pontual.** { *; }
# The Flutter engine references Play Core split-install classes for
# deferred components, which this app does not use (no deferred imports
# anywhere). Silence R8 about the unreferenced-at-runtime paths instead
# of shipping the Play Core dependency for dead code.
-dontwarn com.google.android.play.core.**
