package com.example.sehatpass

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import androidx.core.app.NotificationCompat

class LockScreenEmergencyManager(private val context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        const val PREFS_NAME = "sehatpass_lockscreen_emergency_prefs"
        const val KEY_IS_ENABLED = "is_lockscreen_enabled"
        const val KEY_QR_URL = "emergency_qr_url"
        const val KEY_PATIENT_NAME = "emergency_patient_name"
        const val KEY_BLOOD_GROUP = "emergency_blood_group"
        const val KEY_EMERGENCY_CONTACT = "emergency_contact"
        const val KEY_TOKEN = "emergency_token"

        const val CHANNEL_ID = "sehatpass_emergency_medical_id_channel"
        const val NOTIFICATION_ID = 9110

        @Volatile
        private var instance: LockScreenEmergencyManager? = null

        fun getInstance(context: Context): LockScreenEmergencyManager {
            return instance ?: synchronized(this) {
                instance ?: LockScreenEmergencyManager(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Emergency Medical ID",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Persistent lock-screen access to patient Emergency QR for responders"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
            }

            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun isEnabled(): Boolean {
        return prefs.getBoolean(KEY_IS_ENABLED, false)
    }

    fun getStoredEmergencyData(): Map<String, String?> {
        return mapOf(
            KEY_QR_URL to prefs.getString(KEY_QR_URL, ""),
            KEY_PATIENT_NAME to prefs.getString(KEY_PATIENT_NAME, ""),
            KEY_BLOOD_GROUP to prefs.getString(KEY_BLOOD_GROUP, ""),
            KEY_EMERGENCY_CONTACT to prefs.getString(KEY_EMERGENCY_CONTACT, null),
            KEY_TOKEN to prefs.getString(KEY_TOKEN, "")
        )
    }

    fun enable(
        qrUrl: String,
        patientName: String,
        bloodGroup: String,
        emergencyContact: String?,
        token: String?
    ): Boolean {
        prefs.edit()
            .putBoolean(KEY_IS_ENABLED, true)
            .putString(KEY_QR_URL, qrUrl)
            .putString(KEY_PATIENT_NAME, patientName)
            .putString(KEY_BLOOD_GROUP, bloodGroup)
            .putString(KEY_EMERGENCY_CONTACT, emergencyContact)
            .putString(KEY_TOKEN, token ?: "")
            .apply()

        showEmergencyNotification()
        return true
    }

    fun updateData(
        qrUrl: String,
        patientName: String,
        bloodGroup: String,
        emergencyContact: String?,
        token: String?
    ): Boolean {
        if (!isEnabled()) return false

        prefs.edit()
            .putString(KEY_QR_URL, qrUrl)
            .putString(KEY_PATIENT_NAME, patientName)
            .putString(KEY_BLOOD_GROUP, bloodGroup)
            .putString(KEY_EMERGENCY_CONTACT, emergencyContact)
            .putString(KEY_TOKEN, token ?: "")
            .apply()

        showEmergencyNotification()
        return true
    }

    fun disable(): Boolean {
        prefs.edit()
            .putBoolean(KEY_IS_ENABLED, false)
            .remove(KEY_QR_URL)
            .remove(KEY_PATIENT_NAME)
            .remove(KEY_BLOOD_GROUP)
            .remove(KEY_EMERGENCY_CONTACT)
            .remove(KEY_TOKEN)
            .apply()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
        return true
    }

    fun showEmergencyNotification() {
        if (!isEnabled()) return

        // Explicit Intent to EmergencyQrActivity
        val intent = Intent(context, EmergencyQrActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            flags
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("SehatPass Emergency Medical ID")
            .setContentText("Tap to show Emergency QR for responders")
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "Tap to show Emergency QR for responders. Accessible without unlocking."
                )
            )
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
