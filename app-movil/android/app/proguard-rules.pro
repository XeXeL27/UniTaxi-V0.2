# ML Kit (lectura del carnet). En el APK release R8 quitaba los constructores de los registradores
# de ML Kit, que se crean por reflexion, y toda lectura fallaba (NoSuchMethodException / NPE).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_commons.** { *; }

# La app solo usa el alfabeto latino; los modelos de otros alfabetos no se incluyen y R8 no debe
# exigir sus clases.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
