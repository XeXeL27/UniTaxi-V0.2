package com.taxiuap.movil

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Notificacion fija "UNITAXI" mientras el pasajero busca taxi o esta en viaje y mientras el conductor
 * esta conectado: Android no congela la app minimizada y siguen la consulta, los avisos y el GPS.
 *
 * Reemplaza al servicio de flutter_local_notifications, que llamaba a startForeground sin manejar
 * errores: en Android 14+ iniciar el tipo "ubicacion" sin el permiso concedido (por ejemplo con el GPS
 * apagado, antes de aceptar el permiso) o con la app en segundo plano lanza SecurityException y cerraba
 * la app. Aqui el tipo ubicacion se pide solo con el permiso concedido, si Android lo rechaza se sigue
 * sin el y, si tampoco puede, el servicio se detiene sin cerrar nada. En Android 15+ el tipo dataSync
 * tiene un limite de horas: al cumplirse (onTimeout) se detiene, como exige el sistema.
 */
class ServicioSeguimiento : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val texto = intent?.getStringExtra(EXTRA_TEXTO) ?: "UNITAXI"
        val conUbicacion = intent?.getBooleanExtra(EXTRA_UBICACION, false) ?: false
        val notificacion = crearNotificacion(texto)
        if (!iniciarEnPrimerPlano(notificacion, conUbicacion && tienePermisoUbicacion(this))) {
            stopSelf()
        }
        return START_NOT_STICKY
    }

    /** Intenta con ubicacion (si corresponde) y, si Android la rechaza, solo con sincronizacion. */
    private fun iniciarEnPrimerPlano(notificacion: Notification, conUbicacion: Boolean): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return intentar { startForeground(ID_NOTIFICACION, notificacion) }
        }
        val sincronizacion = ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        if (conUbicacion &&
            intentar { startForeground(ID_NOTIFICACION, notificacion, sincronizacion or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION) }
        ) {
            return true
        }
        return intentar { startForeground(ID_NOTIFICACION, notificacion, sincronizacion) }
    }

    private inline fun intentar(accion: () -> Unit): Boolean = try {
        accion()
        true
    } catch (e: Exception) {
        Log.w(ETIQUETA, "Android no permitio el servicio en primer plano: ${e.message}")
        false
    }

    // Android 15+: se acabo el tiempo permitido para dataSync. Hay que detenerse en pocos segundos
    // o el sistema cierra la app; la app lo vuelve a iniciar al volver a primer plano.
    override fun onTimeout(startId: Int, fgsType: Int) {
        Log.w(ETIQUETA, "Tiempo del servicio en primer plano agotado (tipo $fgsType)")
        detenerPrimerPlano()
        stopSelf()
    }

    @Suppress("DEPRECATION")
    private fun detenerPrimerPlano() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                stopForeground(true)
            }
        } catch (_: Exception) {
        }
    }

    @Suppress("DEPRECATION")
    private fun crearNotificacion(texto: String): Notification {
        val abrir = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val constructor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val gestor = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (gestor.getNotificationChannel(CANAL) == null) {
                val canal = NotificationChannel(CANAL, "Viaje en curso", NotificationManager.IMPORTANCE_LOW)
                canal.description = "Mantiene la app atenta a tu viaje mientras esta minimizada"
                canal.setSound(null, null)
                canal.enableVibration(false)
                gestor.createNotificationChannel(canal)
            }
            Notification.Builder(this, CANAL)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        return constructor
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("UNITAXI")
            .setContentText(texto)
            .setStyle(Notification.BigTextStyle().bigText(texto))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .apply { if (abrir != null) setContentIntent(abrir) }
            .build()
    }

    companion object {
        private const val ETIQUETA = "UnitaxiSeguimiento"
        private const val CANAL = "seguimiento_viaje"
        private const val ID_NOTIFICACION = 7010
        private const val EXTRA_TEXTO = "texto"
        private const val EXTRA_UBICACION = "ubicacion"

        fun tienePermisoUbicacion(contexto: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                contexto.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                contexto.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

        /**
         * Inicia (o actualiza el texto de) el servicio. false si Android no deja iniciarlo ahora (por
         * ejemplo con la app en segundo plano en Android 12+): la app lo reintenta mas tarde.
         */
        fun iniciar(contexto: Context, texto: String, conUbicacion: Boolean): Boolean {
            val intent = Intent(contexto, ServicioSeguimiento::class.java)
                .putExtra(EXTRA_TEXTO, texto)
                .putExtra(EXTRA_UBICACION, conUbicacion)
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    contexto.startForegroundService(intent)
                } else {
                    contexto.startService(intent)
                }
                true
            } catch (e: Exception) {
                Log.w(ETIQUETA, "No se pudo iniciar el seguimiento: ${e.message}")
                false
            }
        }

        fun detener(contexto: Context) {
            try {
                contexto.stopService(Intent(contexto, ServicioSeguimiento::class.java))
            } catch (_: Exception) {
            }
        }
    }
}
