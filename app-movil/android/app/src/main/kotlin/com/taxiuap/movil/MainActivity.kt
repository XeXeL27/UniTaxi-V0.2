package com.taxiuap.movil

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity: la necesita local_auth para el ingreso con huella.
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Vibracion y sonidos de aviso (SonidoAviso en lib/core/sonido.dart): viaje aceptado (la moto
        // encendiendo), servicio nuevo, el taxi llego, viaje finalizado, confirmacion y chat. "sonar"
        // recibe el nombre del audio; la app decide cual suena y cual no (prioridades).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "unitaxi/vibracion").setMethodCallHandler { llamada, resultado ->
            when (llamada.method) {
                "vibrar" -> {
                    vibrar()
                    resultado.success(null)
                }
                "sonar" -> {
                    sonar(llamada.argument<String>("sonido") ?: "moto_encendiendo")
                    resultado.success(null)
                }
                else -> resultado.notImplemented()
            }
        }
        // Notificacion fija mientras hay viaje o el conductor esta conectado (ServicioSeguimiento).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "unitaxi/seguimiento").setMethodCallHandler { llamada, resultado ->
            when (llamada.method) {
                "iniciar" -> resultado.success(
                    ServicioSeguimiento.iniciar(
                        applicationContext,
                        llamada.argument<String>("texto") ?: "UNITAXI",
                        llamada.argument<Boolean>("ubicacion") ?: false,
                    )
                )
                "detener" -> {
                    ServicioSeguimiento.detener(applicationContext)
                    resultado.success(null)
                }
                else -> resultado.notImplemented()
            }
        }
    }

    private var reproductor: MediaPlayer? = null

    // Sonido de aviso una sola vez (sin bucle). Como sonido de notificacion: respeta el modo silencio.
    // Si ya estaba sonando se corta, asi nunca se superponen (la app no pide cortar un aviso importante
    // por uno menor).
    private fun sonar(sonido: String) {
        val recurso = when (sonido) {
            "nuevo_servicio" -> R.raw.nuevo_servicio
            "llego_taxi" -> R.raw.llego_taxi
            "viaje_finalizado" -> R.raw.viaje_finalizado
            "confirmacion" -> R.raw.confirmacion
            "mensaje_chat" -> R.raw.mensaje_chat
            else -> R.raw.moto_encendiendo
        }
        try {
            reproductor?.release()
            reproductor = null
            val atributos = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val nuevo = MediaPlayer.create(this, recurso, atributos, 0) ?: return
            nuevo.isLooping = false
            nuevo.setOnCompletionListener {
                it.release()
                if (reproductor === it) reproductor = null
            }
            reproductor = nuevo
            nuevo.start()
        } catch (e: Exception) {
            reproductor = null
        }
    }

    override fun onDestroy() {
        reproductor?.release()
        reproductor = null
        super.onDestroy()
    }

    // Dos pulsos (los mismos del canal de notificacion de la app). Va marcada como vibracion de
    // NOTIFICACION: sin ese dato Android toma una vibracion corta como respuesta tactil (como el
    // teclado) y la descarta cuando la "vibracion al tocar" del telefono esta apagada.
    private fun vibrar() {
        val vibrador: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        if (vibrador == null || !vibrador.hasVibrator()) return
        val tiempos = longArrayOf(0, 350, 150, 350)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val efecto = VibrationEffect.createWaveform(tiempos, intArrayOf(0, 255, 0, 255), -1)
            vibrador.vibrate(efecto, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_NOTIFICATION))
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val efecto = VibrationEffect.createWaveform(tiempos, intArrayOf(0, 255, 0, 255), -1)
            val atributos = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            @Suppress("DEPRECATION")
            vibrador.vibrate(efecto, atributos)
        } else {
            @Suppress("DEPRECATION")
            vibrador.vibrate(tiempos, -1)
        }
    }
}
