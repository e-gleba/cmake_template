# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in [sdk]/tools/proguard/proguard-android.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.
#
# For more details, see
#   https://developer.android.com/build/shrink-code

# Add any project specific keep options here:

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# No SDL3 rules here on purpose. SDL's own proguard-rules.pro ships from the
# CPM-fetched tree (cmake/cpm/sdl3-config.cmake exports it to
# build/generated/sdl3/) and build.gradle prepends it ahead of this file, so
# an SDL version bump refreshes the JNI keeps automatically — duplicating
# them here would silently pin them to one SDL version.
#
# SDL's onNative* methods need no keeps at all: they are `native` downcalls,
# and the default proguard-android-optimize.txt already preserves native
# method names for JNI linking (-keepclasseswithmembernames class * {
# native <methods>; }).
