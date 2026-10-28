package com.example.pastelaria_app

import android.app.*
import android.content.Intent
import android.os.*

/** Keeps the process eligible during the shift; a killed process needs app reopening. */
class LocalServerService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    override fun onCreate() {
        super.onCreate()
        val channelId = "pastelaria_local_server"
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(channelId, "Servidor da pastelaria", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val pending = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
        val notification = builder.setContentTitle("Servidor local ativo")
            .setContentText("Mantenha a Pastelaria aberta durante o atendimento.")
            .setSmallIcon(android.R.drawable.stat_notify_sync).setContentIntent(pending).setOngoing(true).build()
        startForeground(200, notification)
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "pastelaria:server")
        wakeLock?.acquire(16 * 60 * 60 * 1000L)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onDestroy() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
        super.onDestroy()
    }
}
