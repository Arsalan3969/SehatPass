package com.example.sehatpass

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.sehatpass/lockscreen_emergency"
    private val NOTIFICATION_PERMISSION_CODE = 101
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val manager = LockScreenEmergencyManager.getInstance(this)
            when (call.method) {
                "isEnabled" -> {
                    result.success(manager.isEnabled())
                }
                "enable" -> {
                    val qrUrl = call.argument<String>("qrUrl") ?: ""
                    val patientName = call.argument<String>("patientName") ?: ""
                    val bloodGroup = call.argument<String>("bloodGroup") ?: ""
                    val emergencyContact = call.argument<String>("emergencyContact")
                    val token = call.argument<String>("token")
                    val success = manager.enable(qrUrl, patientName, bloodGroup, emergencyContact, token)
                    result.success(success)
                }
                "updateData" -> {
                    val qrUrl = call.argument<String>("qrUrl") ?: ""
                    val patientName = call.argument<String>("patientName") ?: ""
                    val bloodGroup = call.argument<String>("bloodGroup") ?: ""
                    val emergencyContact = call.argument<String>("emergencyContact")
                    val token = call.argument<String>("token")
                    val success = manager.updateData(qrUrl, patientName, bloodGroup, emergencyContact, token)
                    result.success(success)
                }
                "disable" -> {
                    val success = manager.disable()
                    result.success(success)
                }
                "isNotificationPermissionGranted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.POST_NOTIFICATIONS
                            ) == PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_CODE
                            )
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }
}
