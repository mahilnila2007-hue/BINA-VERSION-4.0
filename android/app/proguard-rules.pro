# Flutter Wrapper rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep MainActivity
-keep class com.binav3.MainActivity { *; }
-keep class com.binav3.** { *; }

# Keep TensorFlow Lite native & JNI classes
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Keep Flutter Blue Plus, Camera, and TTS plugins
-keep class com.jmx.flutter_blue_plus.** { *; }
-keep class io.flutter.plugins.camerax.** { *; }
-keep class com.eyedeadevelopment.fluttertts.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
