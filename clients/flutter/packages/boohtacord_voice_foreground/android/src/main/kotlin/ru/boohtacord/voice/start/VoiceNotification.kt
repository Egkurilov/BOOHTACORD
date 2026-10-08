package ru.boohtacord.voice.start

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build

object VoiceNotification {
    const val ID = 9751
    private const val CHANNEL = "boohtacord_voice_microphone"
    fun create(context: Context): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Голосовой микрофон", NotificationManager.IMPORTANCE_LOW),
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL)
        } else { @Suppress("DEPRECATION") Notification.Builder(context) }
        builder.setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("BOOHTACORD — голосовой микрофон")
            .setContentText("Микрофон включён. Откройте приложение для управления голосом.")
            .setCategory(Notification.CATEGORY_CALL).setOngoing(true).setOnlyAlertOnce(true)
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            builder.setContentIntent(PendingIntent.getActivity(context, ID, it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        }
        return builder.build()
    }
}
