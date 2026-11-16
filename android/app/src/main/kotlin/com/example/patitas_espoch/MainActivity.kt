package com.example.patitas_espoch

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canal = NotificationChannel(
                "patitas_alertas_v1",
                "Alertas de Patitas ESPOCH",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Avisos importantes de Patitas ESPOCH"
                enableVibration(true)
                setShowBadge(true)
            }

            val administrador =
                getSystemService(NotificationManager::class.java)

            administrador.createNotificationChannel(canal)
        }
    }
}

