# ML KIT (VERY IMPORTANT)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# TEXT RECOGNITION (FIX YOUR ERROR)
-keep class com.google.mlkit.vision.text.** { *; }

# FLUTTER
-keep class io.flutter.** { *; }

# UCROP
-keep class com.yalantis.ucrop.** { *; }

# PLAY CORE
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }