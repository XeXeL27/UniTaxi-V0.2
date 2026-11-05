package com.taxiuap.movil

import android.app.Activity
import android.content.Intent
import android.os.Bundle

// Entrada de "Abrir con UNITAXI": al tocar una ubicacion en WhatsApp, Telegram, Messenger o un SMS,
// Android pregunta con que app abrirla y UNITAXI aparece en la lista (filtros del AndroidManifest).
// No muestra nada: pasa el enlace a MainActivity y se cierra. Asi la app se abre siempre en su propia
// tarea (no dentro de WhatsApp) y, si ya estaba abierta, recibe el enlace sin abrirse dos veces.
class AbrirUbicacionActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val enlace = intent?.dataString ?: intent?.getStringExtra(Intent.EXTRA_TEXT)
        val abrir = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (enlace != null) putExtra(MainActivity.EXTRA_UBICACION, enlace)
        }
        try {
            startActivity(abrir)
        } finally {
            finish()
        }
    }
}
