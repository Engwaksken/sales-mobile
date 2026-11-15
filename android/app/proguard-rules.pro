# ML Kit text recognition: only the Latin recognizer is bundled; the plugin
# still references the other script recognizers, so silence R8 about them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
