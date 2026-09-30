# ML Kit (lectura del carnet): la app solo usa el alfabeto latino; los modelos de otros alfabetos
# no se incluyen y R8 no debe exigir sus clases.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
